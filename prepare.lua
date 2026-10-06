-- Each randomized ROM is booted independently. Never reuse another seed's RAM.
-- Real controller inputs perform Mom's Faster FireRed event before saving.
local rb=memory.read_u8
local rd=memory.read_u32_le
local stage,age=0,0
while true do
    local f=miyoo.frame();local key=0;age=age+1
    local sb=rd(0x03005008)
    local group,map=0,0
    if sb>=0x02000000 and sb<0x0203c000 then group=rb(sb+4);map=rb(sb+5) end
    if stage==0 then
        key=f%30<5 and 256 or 0
        if group==4 and map==1 and age>300 then stage=1;age=0 end
    elseif stage==1 then
        -- Close the arrival text; take the clear right-hand path to the stairs.
        key=age<120 and (age%30<5 and 256 or 0) or 128
        if age>120 and memory.read_u16_le(sb)>=10 then stage=2;age=0 end
    elseif stage==2 then
        key=memory.read_u16_le(sb+2)>2 and 16 or 64
        if group==4 and map==0 then stage=3;age=0 end
    elseif stage==3 then
        -- From the stairs, walk down to Mom's row, then approach from her right.
        key=memory.read_u16_le(sb+2)<4 and 32 or 64
        if memory.read_u16_le(sb)<=9 and memory.read_u16_le(sb+2)>=4 then stage=4;age=0 end
    elseif stage==4 then
        key=f%24<4 and 256 or 0
        if group==4 and map==3 then stage=5;age=0 end
    elseif stage==5 then
        key=f%24<4 and 256 or 0
        if age>300 then
            miyoo.setButtons(0)
            console.log('Prepared lab after Mom event at frame',f)
            miyoo.prepareDone()
        end
    end
    if f%600==0 then
        local obj=0x02036e38+rb(0x0203707d)*36
        console.log('PREP',f,stage,group,map,memory.read_u16_le(sb),memory.read_u16_le(sb+2),memory.read_u16_le(obj+16),memory.read_u16_le(obj+18))
    end
    if age>5000 then error('Preparation timed out at stage '..stage) end
    miyoo.setButtons(key)
    emu.frameadvance()
end
