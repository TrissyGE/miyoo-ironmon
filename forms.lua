-- Render tracker popup dialogs on the handheld and provide a touch-style keyboard.
-- All interaction goes through the frontend's D-pad mouse and A click.
MiyooDialogs = { controls = {}, serial = 0, active = nil, keyboard = nil, dropdown = nil, prevClick = false }
local D = MiyooDialogs
forms = {}
local function control(kind,parent,text,x,y,w,h,callback)
    D.serial = D.serial + 1
    local c = { id=D.serial, kind=kind, parent=parent, text=tostring(text or ''), Left=x or 0, Top=y or 0,
        Width=w or math.max(100,#tostring(text or '')*7+12), Height=h or 23, Enabled=true, Visible=true,
        Checked=false, BlocksInputWhenFocused=true, callback=callback }
    D.controls[c.id]=c
    return c.id
end
function forms.newform(w,h,title,onclose)
    local id=control('form',nil,title,0,0,w,h,onclose)
    D.active=id;D.keyboard=nil;D.dropdown=nil;D.prevClick=true
    client.pause();miyoo.setCursor(true)
    return id
end
function forms.destroy(id)
    local c=D.controls[id];if not c then return end
    D.controls[id]=nil
    if D.active==id then
        D.active=nil;D.keyboard=nil;D.dropdown=nil
        client.unpause()
        if Program then Program.redraw(true) end
    end
    for key,v in pairs(D.controls) do if v.parent==id then D.controls[key]=nil end end
    if c.kind=='form' and c.callback then c.callback() end
end
function forms.destroyall() if D.active then forms.destroy(D.active) end;D.controls={} end
function forms.button(id,text,fn,x,y,w,h) return control('button',id,text,x,y,w,h,fn) end
function forms.label(id,text,x,y,w,h) return control('label',id,text,x,y,w,h) end
function forms.checkbox(id,text,x,y) return control('checkbox',id,text,x,y) end
function forms.textbox(id,text,w,h,boxtype,x,y) local key=control('textbox',id,text,x,y,w,h);D.controls[key].boxtype=boxtype;return key end
function forms.dropdown(id,items,x,y,w,h) local key=control('dropdown',id,'',x,y,w,h);forms.setdropdownitems(key,items);return key end
function forms.pictureBox(id,x,y,w,h) return control('picture',id,'',x,y,w,h) end
function forms.gettext(id) return D.controls[id] and D.controls[id].text or '' end
function forms.settext(id,text) if D.controls[id] then D.controls[id].text=tostring(text or '') end end
function forms.getproperty(id,key) local v=D.controls[id] and D.controls[id][key];if type(v)=='boolean' then return v and 'True' or 'False' end;return v==nil and '' or tostring(v) end
function forms.setproperty(id,key,value) if D.controls[id] then D.controls[id][key]=value end end
function forms.ischecked(id) return D.controls[id] and D.controls[id].Checked==true end
function forms.addclick(id,fn) if D.controls[id] then D.controls[id].callback=fn end end
function forms.setdropdownitems(id,items,sort)
    local c=D.controls[id];if not c then return end;c.items={}
    for _,v in pairs(items or {}) do c.items[#c.items+1]=tostring(v) end
    if sort then table.sort(c.items) end
    c.text=c.items[1] or ''
end
function forms.openfile() return '' end
function forms.getMouseX() return input.getmouse().X end
function forms.getMouseY() return input.getmouse().Y end
for _,name in ipairs({'clear','refresh','drawEllipse','drawImage','drawRectangle','drawText'}) do forms[name]=function() end end
local function rect(x,y,w,h,fill) gui.drawRectangle(x,y,w,h,0xFF777777,fill or 0xFF30343A) end
local function text(x,y,value,size) gui.drawText(x,y,tostring(value or ''),0xFFFFFFFF,nil,size or 9) end
local function hit(m,x,y,w,h) return m.X>=x and m.X<x+w and m.Y>=y and m.Y<y+h end
local function key(m,click,x,y,w,h,caption,fn)
    rect(x,y,w,h);text(x+3,y+2,caption,9)
    if click and hit(m,x,y,w,h) then fn() end
end
local function drawKeyboard(m,click)
    local edit=D.keyboard;local c=D.controls[edit.id];if not c then D.keyboard=nil;return end
    rect(0,0,389,159,0xFF15191F);text(8,4,'Edit text - A: key, Done: return to dialog',10)
    rect(8,20,373,20);text(12,23,edit.text:sub(-65)..'_',10)
    local rows={'1234567890+-','qwertyuiop[]','asdfghjkl;:','zxcvbnm,.?!'}
    for row,value in ipairs(rows) do
        for col=1,#value do
            local ch=value:sub(col,col);if edit.upper then ch=ch:upper() end
            key(m,click,8+(col-1)*31,44+(row-1)*21,28,18,ch,function()
                if #edit.text<(tonumber(c.MaxLength) or 200) then edit.text=edit.text..ch end
            end)
        end
    end
    key(m,click,8,132,60,20,'Shift',function() edit.upper=not edit.upper end)
    key(m,click,74,132,65,20,'Space',function() edit.text=edit.text..' ' end)
    key(m,click,145,132,64,20,'Delete',function() edit.text=edit.text:sub(1,-2) end)
    key(m,click,215,132,70,20,'Cancel',function() D.keyboard=nil end)
    key(m,click,291,132,90,20,'Done',function() c.text=edit.text;D.keyboard=nil end)
end
local function drawDropdown(m,click)
    local menu=D.dropdown;local c=D.controls[menu.id];if not c then D.dropdown=nil;return end
    rect(0,0,389,159,0xFF15191F);text(8,4,'Choose an item',10)
    for i=1,15 do
        local index=(menu.page-1)*15+i;local value=c.items[index]
        if value then
            local col=(i-1)%3;local row=math.floor((i-1)/3)
            key(m,click,8+col*127,22+row*21,121,18,value,function() c.text=value;D.dropdown=nil;if c.callback then c.callback() end end)
        end
    end
    key(m,click,8,132,95,20,'Previous',function() menu.page=math.max(1,menu.page-1) end)
    key(m,click,110,132,90,20,'Next',function() menu.page=math.min(math.max(1,math.ceil(#c.items/15)),menu.page+1) end)
    text(210,135,menu.page..'/'..math.max(1,math.ceil(#c.items/15)))
    key(m,click,290,132,90,20,'Cancel',function() D.dropdown=nil end)
end
function D.draw()
    local f=D.controls[D.active];if not f then return end
    local m=input.getmouse();local click=m.Left and not D.prevClick;D.prevClick=m.Left
    if click and os.getenv('IRONMON_QA_NOTE') then print('Dialog click',m.X,m.Y,D.keyboard and 'keyboard' or 'form',D.keyboard and D.keyboard.text or '') end
    if D.keyboard then drawKeyboard(m,click);return end
    if D.dropdown then drawDropdown(m,click);return end
    rect(0,0,389,159,0xFF15191F);text(8,3,f.text,10)
    key(m,click,360,1,27,14,'X',function() forms.destroy(f.id) end)
    local scale=math.min(378/f.Width,135/math.max(1,f.Height-36))
    local ox=6+(378-f.Width*scale)/2;local oy=19
    for _,c in pairs(D.controls) do
        if c.parent==f.id and c.Visible~=false then
            local x=ox+c.Left*scale;local y=oy+c.Top*scale;local w=c.Width*scale;local h=c.Height*scale
            if c.kind~='label' and c.kind~='picture' then rect(x,y,w,h,c.Enabled==false and 0xFF222222 or nil) end
            local caption=c.text:gsub('&&','&')
            if c.kind=='checkbox' then caption=(c.Checked and '[x] ' or '[ ] ')..caption end
            local maxChars=math.max(1,math.floor(w/(4.8*math.max(.6,scale))))
            local offset=0
            for line in (caption..'\n'):gmatch('(.-)\n') do
                while #line>maxChars do text(x+2,y+offset,line:sub(1,maxChars),math.max(7,11*scale));line=line:sub(maxChars+1);offset=offset+9 end
                text(x+2,y+offset,line,math.max(7,11*scale));offset=offset+9
            end
            if click and c.Enabled~=false and hit(m,x,y,w,h) then
                if c.kind=='checkbox' then c.Checked=not c.Checked end
                if c.kind=='textbox' then D.keyboard={id=c.id,text=c.text}
                elseif c.kind=='dropdown' then D.dropdown={id=c.id,page=1}
                elseif c.callback then c.callback() end
            end
        end
    end
end
