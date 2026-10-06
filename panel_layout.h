/* Inverse pointer mapping for rearranged original Tracker panels. */
#ifndef IRONMON_PANEL_LAYOUT_H
#define IRONMON_PANEL_LAYOUT_H
struct panel_region { int sx,sy,sw,sh,dx,dy,dw,dh; };
static int panel_point(const struct panel_region *r,int x,int y,int *lx,int *ly){
    if(r->sw<=0||r->sh<=0||r->dw<=0||r->dh<=0||x<r->dx||y<r->dy||x>=r->dx+r->dw||y>=r->dy+r->dh)return 0;
    *lx=r->sx+(x-r->dx)*r->sw/r->dw;
    *ly=r->sy+(y-r->dy)*r->sh/r->dh;
    return 1;
}
static int panel_pick(const struct panel_region *regions,int count,int x,int y,int *lx,int *ly){
    *lx=*ly=-1;
    for(int i=count-1;i>=0;i--)if(panel_point(&regions[i],x,y,lx,ly))return 1;
    return 0;
}
#endif
