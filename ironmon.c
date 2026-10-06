/* IronMON Miyoo frontend. Runs the upstream tracker through an explicit
 * BizHawk-compatible adapter, alongside the device's libretro GBA core. */
#define _POSIX_C_SOURCE 200809L
#include <SDL/SDL.h>
#include <SDL/SDL_ttf.h>
#include <SDL/SDL_image.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include "libretro.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stdarg.h>
#include <unistd.h>
#include <dlfcn.h>
#include <time.h>
#include <sys/stat.h>
#include <signal.h>
#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_GIF
#include "stb_image.h"

static SDL_Surface *screen, *presentation, *output, *canvas, *game;
static TTF_Font *fonts[32];
static int exit_code=0, paused=0, cursor_mode=0, view_mode=0;
static volatile sig_atomic_t running=1;
static int pad_left=0,pad_top=0,fast_forward=0;
static int ff_toggle=0,ff_latched=0,compact_active=0;
static Uint32 reset_started=0;
static int reset_triggered=0;
static unsigned previous_buttons=0;
static int mouse_x=310,mouse_y=80,mouse_left=0;
static uint16_t buttons=0;
static unsigned pixel_format=RETRO_PIXEL_FORMAT_0RGB1555;
static unsigned long frames=0;
static int test_frames=0;
static unsigned qa_frames=0;
static FILE *replay;
static unsigned long replay_frame=0;static unsigned replay_keys=0;static int replay_pending=0;
static char rom_path[1024],rom_hash[64],rom_name[256];
static uint8_t *rom_data; static size_t rom_size;
static struct retro_memory_descriptor memdesc[64]; static unsigned memcount;
static lua_State *vm,*co;
static int exit_ref=LUA_NOREF;
static int audio_enabled=1;
static unsigned audio_source_rate=65536,audio_phase=0;
static int16_t audio_prev_left=0,audio_prev_right=0;
static int16_t audio_ring[65536]; static unsigned audio_read=0,audio_write=0;
static int16_t keymap[RETRO_DEVICE_ID_JOYPAD_R3+1];

static void (*r_init)(void),(*r_deinit)(void),(*r_run)(void),(*r_reset)(void),(*r_unload_game)(void);
static bool (*r_load_game)(const struct retro_game_info*);
static void (*r_set_environment)(retro_environment_t),(*r_set_video)(retro_video_refresh_t),(*r_set_audio)(retro_audio_sample_t),(*r_set_audio_batch)(retro_audio_sample_batch_t),(*r_set_input_poll)(retro_input_poll_t),(*r_set_input_state)(retro_input_state_t);
static void (*r_get_av)(struct retro_system_av_info*);
static void *(*r_get_memory_data)(unsigned); static size_t (*r_get_memory_size)(unsigned);
static size_t (*r_serialize_size)(void); static bool (*r_serialize)(void*,size_t),(*r_unserialize)(const void*,size_t);

static void core_log(enum retro_log_level level,const char *fmt,...){
    if(level<RETRO_LOG_WARN)return;va_list args;va_start(args,fmt);vfprintf(stderr,fmt,args);va_end(args);
}
static bool environment(unsigned cmd,void *data){
    switch(cmd){
    case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: pixel_format=*(unsigned*)data;return true;
    case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY: *(const char**)data="/mnt/SDCARD/BIOS";return true;
    case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY: *(const char**)data="../data";return true;
    case RETRO_ENVIRONMENT_GET_CAN_DUPE: *(bool*)data=true;return true;
    case RETRO_ENVIRONMENT_GET_LOG_INTERFACE: ((struct retro_log_callback*)data)->log=core_log;return true;
    case RETRO_ENVIRONMENT_SET_MEMORY_MAPS:{
        struct retro_memory_map *m=data;memcount=m->num_descriptors>64?64:m->num_descriptors;
        memcpy(memdesc,m->descriptors,memcount*sizeof(*memdesc));
        for(unsigned i=0;i<memcount;i++)fprintf(stderr,"MEM %u start=%08lx len=%lu ptr=%p\n",i,(unsigned long)memdesc[i].start,(unsigned long)memdesc[i].len,memdesc[i].ptr);
        return true;
    }
    case RETRO_ENVIRONMENT_SET_VARIABLES: return true;
    case RETRO_ENVIRONMENT_GET_VARIABLE: {
        struct retro_variable *v=data;v->value=NULL;
        if(!strcmp(v->key,"mgba_use_bios"))v->value="ON";
        else if(!strcmp(v->key,"mgba_skip_bios"))v->value="ON";
        else if(!strcmp(v->key,"mgba_frameskip"))v->value="disabled";
        else if(!strcmp(v->key,"mgba_color_correction"))v->value="OFF";
        else if(!strcmp(v->key,"mgba_interframe_blending"))v->value="OFF";
        else if(!strcmp(v->key,"mgba_idle_optimization"))v->value="Remove Known";
        return v->value!=NULL;
    }
    case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE: *(bool*)data=false;return true;
    case RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION: *(unsigned*)data=0;return true;
    case RETRO_ENVIRONMENT_GET_FASTFORWARDING: *(bool*)data=fast_forward;return true;
    case RETRO_ENVIRONMENT_GET_LANGUAGE: *(unsigned*)data=RETRO_LANGUAGE_ENGLISH;return true;
    case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:return true;
    default:return false;
    }
}
static void video(const void *data,unsigned w,unsigned h,size_t pitch){
    if(!data)return;
    if(!game||game->w!=(int)w||game->h!=(int)h){if(game)SDL_FreeSurface(game);game=SDL_CreateRGBSurface(SDL_SWSURFACE,w,h,16,0xF800,0x07E0,0x001F,0);}
    SDL_LockSurface(game);
    for(unsigned y=0;y<h;y++){
        uint16_t *dst=(uint16_t*)((uint8_t*)game->pixels+y*game->pitch);
        for(unsigned x=0;x<w;x++){
            if(pixel_format==RETRO_PIXEL_FORMAT_RGB565)dst[x]=*(uint16_t*)((const uint8_t*)data+y*pitch+x*2);
            else if(pixel_format==RETRO_PIXEL_FORMAT_XRGB8888){uint32_t p=*(uint32_t*)((const uint8_t*)data+y*pitch+x*4);dst[x]=((p>>8)&0xF800)|((p>>5)&0x07E0)|((p>>3)&0x001F);}
            else {uint16_t p=*(uint16_t*)((const uint8_t*)data+y*pitch+x*2);dst[x]=((p&0x7C00)<<1)|((p&0x03E0)<<1)|(p&0x001F);}
        }
    }SDL_UnlockSurface(game);
}
static void audio_callback(void *user,Uint8 *out,int length){
    (void)user;int16_t *dst=(int16_t*)out;for(int i=0;i<length/2;i++){dst[i]=(audio_read!=audio_write&&audio_enabled)?audio_ring[audio_read++&65535]:0;}
}
static size_t audio_batch(const int16_t *data,size_t count){
    if(test_frames||!audio_enabled||fast_forward||cursor_mode)return count;
    SDL_LockAudio();
    for(size_t i=0;i<count;i++){
        int left=data[i*2],right=data[i*2+1];audio_phase+=48000;
        while(audio_phase>=audio_source_rate){
            audio_phase-=audio_source_rate;
            if(audio_write-audio_read<65532){
                audio_ring[audio_write++&65535]=(left*(int64_t)(48000-audio_phase)+audio_prev_left*(int64_t)audio_phase)/48000;
                audio_ring[audio_write++&65535]=(right*(int64_t)(48000-audio_phase)+audio_prev_right*(int64_t)audio_phase)/48000;
            }
        }
        audio_prev_left=left;audio_prev_right=right;
    }
    SDL_UnlockAudio();return count;
}
static void audio_sample(int16_t l,int16_t r){int16_t data[]={l,r};audio_batch(data,1);}
static void poll_input(void){}
static int16_t input_state(unsigned port,unsigned device,unsigned index,unsigned id){
    (void)index;if(port||device!=RETRO_DEVICE_JOYPAD||cursor_mode)return 0;
    if((buttons&0x109)==0x109)return 0; /* Consume the held reset combo. */
    if(id==RETRO_DEVICE_ID_JOYPAD_MASK)return buttons;
    return id<16&&((buttons>>id)&1);
}
static uint8_t *memory_ptr(uint32_t address){
    if(address>=0x08000000&&address<0x0E000000){size_t off=(address-0x08000000)%0x02000000;return off<rom_size?rom_data+off:NULL;}
    for(unsigned i=0;i<memcount;i++){
        struct retro_memory_descriptor *d=&memdesc[i];if(!d->ptr||!d->len)continue;
        if(d->select&&(address&d->select)!=(d->start&d->select))continue;
        if(!d->select&&(address<d->start||address>=d->start+d->len))continue;
        size_t off=(address-d->start)&~d->disconnect;if(off<d->len)return (uint8_t*)d->ptr+d->offset+off;
    }
    return NULL;
}
static uint32_t domain_address(lua_State *L,int arg){
    uint32_t a=(uint32_t)luaL_checkinteger(L,1);const char *d=luaL_optstring(L,arg,"");
    if(!strcmp(d,"ROM"))a+=0x08000000;else if(!strcmp(d,"EWRAM"))a+=0x02000000;else if(!strcmp(d,"IWRAM"))a+=0x03000000;return a;
}
static int read_mem(lua_State *L){int n=(int)lua_tointeger(L,lua_upvalueindex(1));uint32_t a=domain_address(L,2),v=0;for(int i=0;i<n;i++){uint8_t*p=memory_ptr(a+i);if(p)v|=(uint32_t)*p<<(8*i);}lua_pushinteger(L,v);return 1;}
static int write_mem(lua_State *L){int n=lua_tointeger(L,lua_upvalueindex(1));uint32_t a=domain_address(L,3),v=luaL_checkinteger(L,2);if(a<0x08000000)for(int i=0;i<n;i++){uint8_t*p=memory_ptr(a+i);if(p)*p=v>>(8*i);}return 0;}
static int read_array(lua_State *L){uint32_t a=domain_address(L,3);int n=luaL_checkinteger(L,2);lua_newtable(L);for(int i=0;i<n;i++){uint8_t*p=memory_ptr(a+i);lua_pushinteger(L,p?*p:0);lua_rawseti(L,-2,i+1);}return 1;}
static int noop(lua_State *L){(void)L;return 0;}
static int yes(lua_State *L){lua_pushboolean(L,1);return 1;}
static int log_lua(lua_State *L){for(int i=1;i<=lua_gettop(L);i++){size_t n;const char*s=luaL_tolstring(L,i,&n);fwrite(s,1,n,stdout);fputc(' ',stdout);lua_pop(L,1);}fputc('\n',stdout);fflush(stdout);return 0;}
static int yield_frame(lua_State *L){return lua_yield(L,0);}
static int get_version(lua_State *L){lua_pushliteral(L,"2.9.1");return 1;}
static int get_rom_name(lua_State *L){lua_pushstring(L,rom_name);return 1;}
static int get_rom_hash(lua_State *L){lua_pushstring(L,rom_hash);return 1;}
static int get_fps(lua_State *L){lua_pushnumber(L,60);return 1;}
static int get_frame(lua_State *L){lua_pushinteger(L,frames);return 1;}
static int raw_buttons(lua_State *L){lua_pushinteger(L,buttons);return 1;}
static int compact_lua(lua_State *L){lua_pushboolean(L,compact_active);return 1;}
static int ff_config(lua_State *L){ff_toggle=lua_toboolean(L,1);ff_latched=0;return 0;}
static int set_buttons(lua_State *L){buttons=luaL_checkinteger(L,1);return 0;}
static int set_padding(lua_State *L){
    int l=luaL_checkinteger(L,1),t=luaL_checkinteger(L,2),r=luaL_checkinteger(L,3),b=luaL_checkinteger(L,4);
    int w=240+l+r,h=160+t+b;if(w<240||w>1024||h<160||h>1024)return luaL_error(L,"Invalid tracker padding");
    if(w!=canvas->w||h!=canvas->h){SDL_FreeSurface(canvas);canvas=SDL_CreateRGBSurface(SDL_SWSURFACE,w,h,16,0xF800,0x07E0,0x001F,0);SDL_FillRect(canvas,NULL,0);}pad_left=l;pad_top=t;return 0;
}
static int get_sound(lua_State *L){lua_pushboolean(L,audio_enabled);return 1;}
static int set_sound(lua_State *L){audio_enabled=lua_toboolean(L,1);return 0;}
static int get_mouse(lua_State *L){lua_newtable(L);lua_pushinteger(L,mouse_x);lua_setfield(L,-2,"X");lua_pushinteger(L,mouse_y);lua_setfield(L,-2,"Y");lua_pushboolean(L,mouse_left);lua_setfield(L,-2,"Left");lua_pushinteger(L,0);lua_setfield(L,-2,"Wheel");return 1;}
static int get_joy(lua_State *L){
    const char*names[]={"B","Y","Select","Start","Up","Down","Left","Right","A","X","L","R"};
    lua_newtable(L);for(int i=0;i<12;i++){lua_pushboolean(L,!cursor_mode&&((buttons>>i)&1));lua_setfield(L,-2,names[i]);}return 1;
}
static int pause_lua(lua_State *L){(void)L;paused=1;return 0;}
static int unpause_lua(lua_State *L){(void)L;paused=0;return 0;}
static int transform(lua_State *L){lua_newtable(L);lua_pushvalue(L,1);lua_setfield(L,-2,"x");lua_pushvalue(L,2);lua_setfield(L,-2,"y");return 1;}
static int zero(lua_State *L){lua_pushinteger(L,0);return 1;}
static int set_exit_hook(lua_State *L){if(exit_ref!=LUA_NOREF)luaL_unref(L,LUA_REGISTRYINDEX,exit_ref);lua_pushvalue(L,1);exit_ref=luaL_ref(L,LUA_REGISTRYINDEX);return 0;}
static int next_run(lua_State *L){exit_code=42;running=0;return lua_yield(L,0);}
static int set_cursor(lua_State *L){cursor_mode=lua_toboolean(L,1);view_mode=0;buttons=0;mouse_left=0;return 0;}

static uint32_t color(lua_State *L,int i,uint32_t def){return lua_isnoneornil(L,i)?def:(uint32_t)lua_tointeger(L,i);}
static uint32_t mapped_color(uint32_t c){return SDL_MapRGB(canvas->format,(c>>16)&255,(c>>8)&255,c&255);}
static void pixel(int x,int y,uint32_t c){if(x>=0&&y>=0&&x<canvas->w&&y<canvas->h)*((uint16_t*)((uint8_t*)canvas->pixels+y*canvas->pitch)+x)=mapped_color(c);}
static void line(int x1,int y1,int x2,int y2,uint32_t c){int dx=abs(x2-x1),sx=x1<x2?1:-1,dy=-abs(y2-y1),sy=y1<y2?1:-1,e=dx+dy;for(;;){pixel(x1,y1,c);if(x1==x2&&y1==y2)break;int e2=2*e;if(e2>=dy){e+=dy;x1+=sx;}if(e2<=dx){e+=dx;y1+=sy;}}}
static int draw_pixel(lua_State *L){pixel(luaL_checknumber(L,1),luaL_checknumber(L,2),color(L,3,0xFFFFFFFF));return 0;}
static int draw_line(lua_State *L){line(luaL_checknumber(L,1),luaL_checknumber(L,2),luaL_checknumber(L,3),luaL_checknumber(L,4),color(L,5,0xFFFFFFFF));return 0;}
static int draw_rect(lua_State *L){
    int x=luaL_checknumber(L,1),y=luaL_checknumber(L,2),w=luaL_checknumber(L,3),h=luaL_checknumber(L,4);if(w<0||h<0)return 0;
    if(!lua_isnoneornil(L,6)&&((color(L,6,0)>>24)!=0)){SDL_Rect r={x,y,w+1,h+1};SDL_FillRect(canvas,&r,mapped_color(color(L,6,0)));}
    uint32_t c=color(L,5,0xFFFFFFFF);if(c>>24){line(x,y,x+w,y,c);line(x,y+h,x+w,y+h,c);line(x,y,x,y+h,c);line(x+w,y,x+w,y+h,c);}return 0;
}
static int draw_ellipse(lua_State *L){
    int x=luaL_checknumber(L,1),y=luaL_checknumber(L,2),w=luaL_checknumber(L,3),h=luaL_checknumber(L,4);if(w<1||h<1)return 0;
    uint32_t b=color(L,5,0xFFFFFFFF),f=color(L,6,0);for(int yy=0;yy<=h;yy++)for(int xx=0;xx<=w;xx++){double a=(2.0*xx/w-1),z=(2.0*yy/h-1),v=a*a+z*z;if(v<=1&&(f>>24))pixel(x+xx,y+yy,f);if(v<=1&&v>=1-4.0/(w<h?w:h)&&(b>>24))pixel(x+xx,y+yy,b);}return 0;
}
static TTF_Font *font_for(int size){if(size<5)size=5;if(size>31)size=31;if(!fonts[size])fonts[size]=TTF_OpenFont("../font.ttf",size);return fonts[size];}
static void text_at(SDL_Surface *target,int x,int y,const char *text,uint32_t c,int size){
    if(!text||!*text)return;TTF_Font *f=font_for(size);if(!f)return;
    SDL_Color sc={(c>>16)&255,(c>>8)&255,c&255,0};SDL_Surface*s=TTF_RenderUTF8_Blended(f,text,sc);if(s){SDL_Rect r={x,y,0,0};SDL_BlitSurface(s,NULL,target,&r);SDL_FreeSurface(s);}
}
static int compact_text(lua_State *L){text_at(screen,luaL_checkinteger(L,1),luaL_checkinteger(L,2),luaL_checkstring(L,3),color(L,4,0xffffffff),luaL_optinteger(L,5,17));return 0;}
static int compact_rect(lua_State *L){SDL_Rect r={luaL_checkinteger(L,1),luaL_checkinteger(L,2),luaL_checkinteger(L,3),luaL_checkinteger(L,4)};SDL_FillRect(screen,&r,mapped_color(color(L,5,0xff17202b)));return 0;}
static int draw_text(lua_State *L){text_at(canvas,luaL_checknumber(L,1),luaL_checknumber(L,2),luaL_checkstring(L,3),color(L,4,0xFFFFFFFF),luaL_optnumber(L,6,9));return 0;}
struct image_cache{char *path;SDL_Surface *image;};static struct image_cache images[2048];static unsigned image_count;
static SDL_Surface *cached_image(const char *path){
    for(unsigned i=0;i<image_count;i++)if(!strcmp(images[i].path,path))return images[i].image;
    SDL_Surface*s=IMG_Load(path);
    if(!s){int w,h,n;unsigned char*p=stbi_load(path,&w,&h,&n,4);if(p){
        s=SDL_CreateRGBSurface(SDL_SWSURFACE|SDL_SRCALPHA,w,h,32,0xFF,0xFF00,0xFF0000,0xFF000000);
        for(int y=0;y<h;y++)memcpy((uint8_t*)s->pixels+y*s->pitch,p+y*w*4,w*4);stbi_image_free(p);
    }}
    if(image_count<2048){images[image_count].path=strdup(path);images[image_count++].image=s;}
    if(!s)fprintf(stderr,"Image failed %s: %s\n",path,IMG_GetError());return s;
}
static int draw_image(lua_State *L){
    SDL_Surface*s=cached_image(luaL_checkstring(L,1));if(!s)return 0;int x=luaL_checknumber(L,2),y=luaL_checknumber(L,3),w=luaL_optnumber(L,4,s->w),h=luaL_optnumber(L,5,s->h);
    SDL_Rect dst={x,y,w,h};if(w==s->w&&h==s->h)SDL_BlitSurface(s,NULL,canvas,&dst);else {SDL_Surface*t=SDL_CreateRGBSurface(SDL_SWSURFACE,w,h,s->format->BitsPerPixel,s->format->Rmask,s->format->Gmask,s->format->Bmask,s->format->Amask);if(s->format->palette)SDL_SetColors(t,s->format->palette->colors,0,s->format->palette->ncolors);if(s->flags&SDL_SRCCOLORKEY)SDL_SetColorKey(t,SDL_SRCCOLORKEY,s->format->colorkey);if(s->flags&SDL_SRCALPHA)SDL_SetAlpha(t,SDL_SRCALPHA,255);SDL_SoftStretch(s,NULL,t,NULL);SDL_BlitSurface(t,NULL,canvas,&dst);SDL_FreeSurface(t);}return 0;
}
static int draw_image_region(lua_State *L){
    SDL_Surface*s=cached_image(luaL_checkstring(L,1));if(!s)return 0;SDL_Rect src={luaL_checknumber(L,2),luaL_checknumber(L,3),luaL_checknumber(L,4),luaL_checknumber(L,5)},dst={luaL_checknumber(L,6),luaL_checknumber(L,7),0,0};SDL_BlitSurface(s,&src,canvas,&dst);return 0;
}
static int clear_images(lua_State *L){(void)L;for(unsigned i=0;i<image_count;i++){free(images[i].path);if(images[i].image)SDL_FreeSurface(images[i].image);}image_count=0;return 0;}
static void save_ram(void){size_t n=r_get_memory_size(RETRO_MEMORY_SAVE_RAM);void*p=r_get_memory_data(RETRO_MEMORY_SAVE_RAM);if(n&&p){FILE*f=fopen("../data/current.srm.tmp","wb");if(f){fwrite(p,1,n,f);fclose(f);rename("../data/current.srm.tmp","../data/current.srm");}}}
static int saveram_lua(lua_State *L){(void)L;save_ram();return 0;}
static void save_state(const char *path){size_t n=r_serialize_size();void*p=malloc(n);if(n&&p&&r_serialize(p,n)){char tmp[1200];snprintf(tmp,sizeof(tmp),"%s.tmp",path);FILE*f=fopen(tmp,"wb");if(f){int ok=fwrite(p,1,n,f)==n;ok=fclose(f)==0&&ok;if(ok)rename(tmp,path);}}free(p);}
static void load_state(const char *path){FILE*f=fopen(path,"rb");if(!f)return;fseek(f,0,SEEK_END);size_t n=ftell(f);rewind(f);void*p=malloc(n);if(p&&fread(p,1,n,f)==n)r_unserialize(p,n);free(p);fclose(f);}
static int save_state_lua(lua_State *L){save_state(luaL_checkstring(L,1));return 0;}
static int checkpoint(lua_State *L){(void)L;if(!test_frames){save_ram();save_state("../data/current.state");}return 0;}
static int prep_done(lua_State *L){
    (void)L;save_state("../data/lab.state");
    FILE*f=fopen("../data/lab.sha1","w");if(f){fprintf(f,"%s\n",rom_hash);fclose(f);}
    running=0;exit_code=43;return lua_yield(L,0);
}
static int load_state_lua(lua_State *L){(void)L;fprintf(stderr,"Strict Standard: Lua state restore blocked\n");return 0;}
struct core_state {void *data;size_t size;};
static int remove_core_state(lua_State *L){struct core_state*s=luaL_checkudata(L,1,"ironmon.state");free(s->data);s->data=NULL;s->size=0;return 0;}
static int save_core_state(lua_State *L){
    struct core_state*s=lua_newuserdatauv(L,sizeof(*s),0);s->size=r_serialize_size();s->data=malloc(s->size);
    luaL_setmetatable(L,"ironmon.state");if(!s->data||!r_serialize(s->data,s->size))return luaL_error(L,"Unable to create restore point");return 1;
}
static int load_core_state(lua_State *L){(void)L;fprintf(stderr,"Strict Standard: Lua rewind blocked\n");return 0;}
static void setfunc(lua_State *L,const char *name,lua_CFunction func){lua_pushcfunction(L,func);lua_setfield(L,-2,name);}
static void memory_funcs(lua_State *L,const char*name){
    lua_newtable(L);const char*reads[]={"read_u8","read_u16_le","read_u32_le"};const char*writes[]={"write_u8","write_u16_le","write_u32_le"};int widths[]={1,2,4};
    for(int i=0;i<3;i++){lua_pushinteger(L,widths[i]);lua_pushcclosure(L,read_mem,1);lua_setfield(L,-2,reads[i]);lua_pushinteger(L,widths[i]);lua_pushcclosure(L,write_mem,1);lua_setfield(L,-2,writes[i]);}setfunc(L,"read_bytes_as_array",read_array);lua_setglobal(L,name);
}
static void register_api(lua_State *L){
    memory_funcs(L,"memory");
    lua_newtable(L);setfunc(L,"frameadvance",yield_frame);lua_setglobal(L,"emu");
    lua_newtable(L);setfunc(L,"log",log_lua);setfunc(L,"clear",noop);lua_setglobal(L,"console");
    lua_newtable(L);setfunc(L,"getversion",get_version);setfunc(L,"SetGameExtraPadding",set_padding);setfunc(L,"get_approx_framerate",get_fps);setfunc(L,"GetSoundOn",get_sound);setfunc(L,"SetSoundOn",set_sound);setfunc(L,"saveram",saveram_lua);setfunc(L,"pause",pause_lua);setfunc(L,"unpause",unpause_lua);setfunc(L,"transformPoint",transform);setfunc(L,"xpos",zero);setfunc(L,"ypos",zero);setfunc(L,"gettool",noop);lua_setglobal(L,"client");
    lua_newtable(L);setfunc(L,"getromname",get_rom_name);setfunc(L,"getromhash",get_rom_hash);lua_setglobal(L,"gameinfo");
    lua_newtable(L);setfunc(L,"getmouse",get_mouse);lua_setglobal(L,"input");
    lua_newtable(L);setfunc(L,"get",get_joy);lua_setglobal(L,"joypad");
    lua_newtable(L);setfunc(L,"onexit",set_exit_hook);setfunc(L,"onconsoleclose",noop);lua_setglobal(L,"event");
    lua_newtable(L);setfunc(L,"save",save_state_lua);setfunc(L,"load",load_state_lua);lua_setglobal(L,"savestate");
    luaL_newmetatable(L,"ironmon.state");setfunc(L,"__gc",remove_core_state);lua_pop(L,1);
    lua_newtable(L);setfunc(L,"savecorestate",save_core_state);setfunc(L,"loadcorestate",load_core_state);setfunc(L,"removestate",remove_core_state);lua_setglobal(L,"memorysavestate");
    lua_newtable(L);setfunc(L,"drawText",draw_text);setfunc(L,"drawRectangle",draw_rect);setfunc(L,"drawEllipse",draw_ellipse);setfunc(L,"drawPixel",draw_pixel);setfunc(L,"drawLine",draw_line);setfunc(L,"drawImage",draw_image);setfunc(L,"drawImageRegion",draw_image_region);setfunc(L,"clearImageCache",clear_images);setfunc(L,"defaultTextBackground",noop);lua_setglobal(L,"gui");
    lua_newtable(L);setfunc(L,"newRun",next_run);setfunc(L,"setCursor",set_cursor);setfunc(L,"frame",get_frame);setfunc(L,"buttons",raw_buttons);setfunc(L,"compact",compact_lua);setfunc(L,"fastForwardToggle",ff_config);setfunc(L,"text",compact_text);setfunc(L,"rect",compact_rect);setfunc(L,"setButtons",set_buttons);setfunc(L,"prepareDone",prep_done);setfunc(L,"checkpoint",checkpoint);lua_setglobal(L,"miyoo");
}
static int call_bool(const char *table,const char *method,int fallback){
    int top=lua_gettop(vm),result=fallback;lua_getglobal(vm,table);
    if(lua_istable(vm,-1)){lua_getfield(vm,-1,method);if(lua_isfunction(vm,-1)&&lua_pcall(vm,0,1,0)==LUA_OK)result=lua_toboolean(vm,-1);}
    lua_settop(vm,top);return result;
}
static void call_void(const char *table,const char *method){
    int top=lua_gettop(vm);lua_getglobal(vm,table);
    if(lua_istable(vm,-1)){lua_getfield(vm,-1,method);if(lua_isfunction(vm,-1)&&lua_pcall(vm,0,0,0)!=LUA_OK){fprintf(stderr,"%s.%s: %s\n",table,method,lua_tostring(vm,-1));exit_code=3;running=0;}}
    lua_settop(vm,top);
}
static void input_events(void){
    SDL_Event e;while(SDL_PollEvent(&e)){
        if(e.type==SDL_QUIT){running=0;continue;}if(e.type!=SDL_KEYDOWN&&e.type!=SDL_KEYUP)continue;
        int down=e.type==SDL_KEYDOWN,k=e.key.keysym.sym;
        if(down&&k==SDLK_ESCAPE){running=0;continue;}
        if(down&&k==SDLK_LSHIFT){if(call_bool("MiyooQol","allowOriginal",1))cursor_mode=!cursor_mode;mouse_left=0;continue;}
        if(down&&k==SDLK_LALT){view_mode=(view_mode+1)%4;continue;}
        if(down&&k==SDLK_TAB)cursor_mode=0;
        for(unsigned i=0;i<16;i++)if(keymap[i]&&k==keymap[i]){if(down)buttons|=1<<i;else buttons&=~(1<<i);}
    }
    if(cursor_mode){
        if(buttons&(1<<RETRO_DEVICE_ID_JOYPAD_LEFT))mouse_x-=2;
        if(buttons&(1<<RETRO_DEVICE_ID_JOYPAD_RIGHT))mouse_x+=2;
        if(buttons&(1<<RETRO_DEVICE_ID_JOYPAD_UP))mouse_y-=2;
        if(buttons&(1<<RETRO_DEVICE_ID_JOYPAD_DOWN))mouse_y+=2;
        if(mouse_x<0)mouse_x=0;if(mouse_x>=canvas->w)mouse_x=canvas->w-1;if(mouse_y<0)mouse_y=0;if(mouse_y>=canvas->h)mouse_y=canvas->h-1;
        mouse_left=(buttons>>RETRO_DEVICE_ID_JOYPAD_A)&1;
    }else mouse_left=0;
    unsigned pressed=buttons&~previous_buttons;
    if(pressed&(1<<RETRO_DEVICE_ID_JOYPAD_R2))ff_latched=!ff_latched;
    fast_forward=!cursor_mode&&!paused&&(ff_toggle?ff_latched:((buttons>>RETRO_DEVICE_ID_JOYPAD_R2)&1));
    const unsigned reset_mask=(1<<RETRO_DEVICE_ID_JOYPAD_A)|(1<<RETRO_DEVICE_ID_JOYPAD_B)|(1<<RETRO_DEVICE_ID_JOYPAD_START);
    if(!test_frames&&(buttons&reset_mask)==reset_mask){
        if(!reset_started&&!reset_triggered)reset_started=SDL_GetTicks();
        if(!reset_triggered&&SDL_GetTicks()-reset_started>=2000){
            if(call_bool("MiyooRules","canReset",0)){call_void("MiyooRules","save");exit_code=42;running=0;}
            reset_triggered=1;
        }
    }else {reset_started=0;reset_triggered=0;}
    previous_buttons=buttons;
}
static void present(void){
    /* The Mini Plus LCD is mounted upside down relative to the raw framebuffer.
       Rotate only the final surface; tracker and input coordinates stay logical. */
    for(int y=0;y<480;y++){
        uint16_t*dst=(uint16_t*)((uint8_t*)presentation->pixels+y*presentation->pitch);
        uint16_t*src=(uint16_t*)((uint8_t*)screen->pixels+(479-y)*screen->pitch);
        for(int x=0;x<640;x++)dst[x]=src[639-x];
    }
    SDL_BlitSurface(presentation,NULL,output,NULL);SDL_Flip(output);
}
static void display(void){
    int needs_native=call_bool("MiyooQol","needsNative",0);
    if(needs_native||(!cursor_mode&&view_mode!=3)){
        SDL_FillRect(screen,NULL,0);compact_active=needs_native||view_mode==1||(view_mode==0&&call_bool("MiyooQol","isCompact",1));
        SDL_Rect dest=compact_active?(SDL_Rect){0,0,480,320}:(SDL_Rect){0,26,640,427};
        if(game)SDL_SoftStretch(game,NULL,screen,&dest);
        call_void("MiyooQol","draw");present();return;
    }
    compact_active=0;
    SDL_FillRect(screen,NULL,0);SDL_Rect source={0,0,canvas->w,canvas->h};
    int w=640,h=(int)(source.h*(640.0/source.w));if(h>420){h=420;w=(int)(source.w*(420.0/source.h));}SDL_Rect dest={(640-w)/2,(440-h)/2,w,h};
    SDL_SoftStretch(canvas,&source,screen,&dest);
    if(cursor_mode){int x=dest.x+(mouse_x-source.x)*dest.w/source.w,y=dest.y+(mouse_y-source.y)*dest.h/source.h;SDL_Rect a={x-4,y,9,1},b={x,y-4,1,9};SDL_FillRect(screen,&a,0xFFFF);SDL_FillRect(screen,&b,0xFFFF);}
    text_at(screen,12,444,cursor_mode?"Tracker: D-pad = cursor   A = click   X = play":"X: Tracker cursor   Y: View   Menu: Save & exit",0xFFEEEEEE,16);
    text_at(screen,12,464,"New run: A + B + Start    R2: Fast forward",0xFFAAAAAA,13);
    present();
}
static void load_core(const char *path){
    void*handle=dlopen(path,RTLD_NOW|RTLD_LOCAL);if(!handle){fprintf(stderr,"Core load failed: %s\n",dlerror());exit(2);}
#define SYM(v,n) do{v=dlsym(handle,n);if(!v){fprintf(stderr,"Missing core export %s\n",n);exit(2);}}while(0)
    SYM(r_init,"retro_init");SYM(r_deinit,"retro_deinit");SYM(r_run,"retro_run");SYM(r_reset,"retro_reset");SYM(r_load_game,"retro_load_game");SYM(r_unload_game,"retro_unload_game");SYM(r_set_environment,"retro_set_environment");SYM(r_set_video,"retro_set_video_refresh");SYM(r_set_audio,"retro_set_audio_sample");SYM(r_set_audio_batch,"retro_set_audio_sample_batch");SYM(r_set_input_poll,"retro_set_input_poll");SYM(r_set_input_state,"retro_set_input_state");SYM(r_get_av,"retro_get_system_av_info");SYM(r_get_memory_data,"retro_get_memory_data");SYM(r_get_memory_size,"retro_get_memory_size");SYM(r_serialize_size,"retro_serialize_size");SYM(r_serialize,"retro_serialize");SYM(r_unserialize,"retro_unserialize");
    r_set_environment(environment);r_set_video(video);r_set_audio(audio_sample);r_set_audio_batch(audio_batch);r_set_input_poll(poll_input);r_set_input_state(input_state);r_init();
}
static void hash_rom(void){char cmd[1200];snprintf(cmd,sizeof(cmd),"sha1sum '%s'",rom_path);FILE*p=popen(cmd,"r");if(p){if(fgets(rom_hash,sizeof(rom_hash),p))rom_hash[40]=0;pclose(p);}if(!*rom_hash)snprintf(rom_hash,sizeof(rom_hash),"%08lx",(unsigned long)rom_size);}
static void stop_signal(int sig){(void)sig;running=0;}
int main(int argc,char**argv){
    if(argc<3){fprintf(stderr,"Usage: ironmon CORE ROM [TEST_FRAMES]\n");return 2;}setvbuf(stdout,NULL,_IOLBF,0);
    strncpy(rom_path,argv[2],sizeof(rom_path)-1);const char*name=strrchr(rom_path,'/');strncpy(rom_name,name?name+1:rom_path,sizeof(rom_name)-1);char*ext=strrchr(rom_name,'.');if(ext)*ext=0;
    if(argc>3)test_frames=atoi(argv[3]);
    const char*qa=getenv("IRONMON_QA_FRAMES");if(qa)qa_frames=atoi(qa);
    signal(SIGTERM,stop_signal);signal(SIGINT,stop_signal);signal(SIGHUP,stop_signal);
    if(argc>4){replay=fopen(argv[4],"r");if(replay)replay_pending=fscanf(replay,"%lu %x",&replay_frame,&replay_keys)==2;}
    FILE*f=fopen(rom_path,"rb");if(!f){perror(rom_path);return 2;}fseek(f,0,SEEK_END);rom_size=ftell(f);rewind(f);rom_data=malloc(rom_size);if(!rom_data||fread(rom_data,1,rom_size,f)!=rom_size){fclose(f);return 2;}fclose(f);hash_rom();
    if(SDL_Init(SDL_INIT_VIDEO|SDL_INIT_AUDIO|SDL_INIT_TIMER)<0){fprintf(stderr,"SDL init %s\n",SDL_GetError());return 2;}
    output=SDL_SetVideoMode(640,480,32,SDL_SWSURFACE);if(!output){fprintf(stderr,"Video mode %s\n",SDL_GetError());return 2;}
    /* Firmware GFX scan-out expects a 32-bit framebuffer. Keep all scaling in
       a separate RGB565 software surface and convert only when presenting. */
    screen=SDL_CreateRGBSurface(SDL_SWSURFACE,640,480,16,0xF800,0x07E0,0x001F,0);SDL_ShowCursor(SDL_DISABLE);TTF_Init();
    presentation=SDL_CreateRGBSurface(SDL_SWSURFACE,640,480,16,0xF800,0x07E0,0x001F,0);
    canvas=SDL_CreateRGBSurface(SDL_SWSURFACE,390,160,16,0xF800,0x07E0,0x001F,0);SDL_FillRect(canvas,NULL,0);
    keymap[RETRO_DEVICE_ID_JOYPAD_A]=SDLK_SPACE;keymap[RETRO_DEVICE_ID_JOYPAD_B]=SDLK_LCTRL;keymap[RETRO_DEVICE_ID_JOYPAD_START]=SDLK_RETURN;keymap[RETRO_DEVICE_ID_JOYPAD_SELECT]=SDLK_RCTRL;keymap[RETRO_DEVICE_ID_JOYPAD_UP]=SDLK_UP;keymap[RETRO_DEVICE_ID_JOYPAD_DOWN]=SDLK_DOWN;keymap[RETRO_DEVICE_ID_JOYPAD_LEFT]=SDLK_LEFT;keymap[RETRO_DEVICE_ID_JOYPAD_RIGHT]=SDLK_RIGHT;keymap[RETRO_DEVICE_ID_JOYPAD_L]=SDLK_e;keymap[RETRO_DEVICE_ID_JOYPAD_R]=SDLK_t;keymap[RETRO_DEVICE_ID_JOYPAD_R2]=SDLK_BACKSPACE;
    keymap[RETRO_DEVICE_ID_JOYPAD_L2]=SDLK_TAB;
    load_core(argv[1]);struct retro_game_info info={rom_path,rom_data,rom_size,NULL};if(!r_load_game(&info)){fprintf(stderr,"Game load failed\n");return 2;}
    size_t n=r_get_memory_size(RETRO_MEMORY_SAVE_RAM);void*save=r_get_memory_data(RETRO_MEMORY_SAVE_RAM);f=fopen("../data/current.srm","rb");if(f){fread(save,1,n,f);fclose(f);}if(!test_frames)load_state("../data/current.state");else if(argc>5)load_state("../data/test.state");
    struct retro_system_av_info av;r_get_av(&av);audio_source_rate=(unsigned)av.timing.sample_rate;SDL_AudioSpec desired={0};desired.freq=48000;desired.format=AUDIO_S16SYS;desired.channels=2;desired.samples=1024;desired.callback=audio_callback;if(!test_frames){if(SDL_OpenAudio(&desired,NULL)==0){SDL_PauseAudio(0);fprintf(stderr,"Audio opened at %d Hz\n",desired.freq);}else fprintf(stderr,"Audio open failed: %s\n",SDL_GetError());}
    vm=luaL_newstate();luaL_openlibs(vm);register_api(vm);co=lua_newthread(vm);
    const char*bootstrap=getenv("IRONMON_BOOTSTRAP");luaL_loadfile(co,bootstrap?bootstrap:"../bootstrap.lua");
    Uint32 start=SDL_GetTicks(),last_save=start;double deadline=start;int lua_status=LUA_YIELD,nresults=0;
    while(running){
        if(replay){while(replay_pending&&frames>=replay_frame){buttons=replay_keys&0xFFFF;if(replay_keys&0x10000)cursor_mode=!cursor_mode;if(replay_keys&0x20000)view_mode=(view_mode+1)%4;if(replay_keys&0x40000)running=0;replay_pending=fscanf(replay,"%lu %x",&replay_frame,&replay_keys)==2;}}input_events();if(!paused&&!cursor_mode)r_run();frames++;
        if(game){SDL_Rect dst={pad_left,pad_top,0,0};SDL_BlitSurface(game,NULL,canvas,&dst);}
        if(lua_status==LUA_YIELD){lua_status=lua_resume(co,vm,0,&nresults);if(lua_status!=LUA_YIELD&&lua_status!=LUA_OK){fprintf(stderr,"TRACKER ERROR: %s\n",lua_tostring(co,-1));running=0;exit_code=3;}}
        if(frames%2==0&&!getenv("IRONMON_PREPARING"))display();
        if(test_frames&&(int)frames>=test_frames){display();SDL_SaveBMP(screen,"../test.bmp");save_state("../data/test.state");running=0;}
        if(qa_frames&&frames>=qa_frames){display();SDL_SaveBMP(screen,"../test.bmp");running=0;}
        if(!test_frames&&SDL_GetTicks()-last_save>=60000){call_void("MiyooRules","save");save_ram();save_state("../data/current.state");last_save=SDL_GetTicks();}
        if(!test_frames){Uint32 now=SDL_GetTicks();if(!fast_forward){deadline+=1000.0/av.timing.fps;if(deadline>now)SDL_Delay((Uint32)(deadline-now));else if(now>deadline+100)deadline=now;}else deadline=now;}
    }
    fprintf(stderr,"Completed %lu frames in %u ms, exit %d\n",frames,SDL_GetTicks()-start,exit_code);
    call_void("MiyooRules","save");
    if(exit_ref!=LUA_NOREF){lua_rawgeti(vm,LUA_REGISTRYINDEX,exit_ref);if(lua_pcall(vm,0,0,0)!=LUA_OK)fprintf(stderr,"Exit hook: %s\n",lua_tostring(vm,-1));}
    if(!test_frames){save_ram();save_state("../data/current.state");}
    if(!test_frames&&exit_code==42){SDL_FillRect(screen,NULL,0);text_at(screen,120,190,"Neuer IronMON-Run wird erzeugt...",0xFFFFFFFF,22);text_at(screen,180,235,"Bitte kurz warten.",0xFFAAAAAA,18);present();}
    lua_close(vm);r_unload_game();r_deinit();SDL_CloseAudio();SDL_Quit();return exit_code;
}
