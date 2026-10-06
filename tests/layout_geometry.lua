local L=dofile('../tracker_layout.lua')
for _,game in ipairs({{512,342},{480,320}}) do for _,ballPicker in ipairs({false,true}) do
    local panels=L.panels(game[1],game[2],ballPicker)
    for _,r in ipairs(panels) do
        assert(r[1]>=0 and r[2]>=0 and r[3]>0 and r[4]>0 and r[1]+r[3]<=390 and r[2]+r[4]<=160,'source outside original canvas')
        assert(r[5]>=0 and r[6]>=0 and r[7]>0 and r[8]>0 and r[5]+r[7]<=640 and r[6]+r[8]<=480,'destination outside LCD')
        assert(math.abs((r[7]/r[3])/(r[8]/r[4])-1)<.025,'panel aspect ratio distorted')
    end
    -- Every class of original main-screen interaction remains visible.
    for _,point in ipairs({{373,13},{335,10},{260,15},{260,43},{270,68},{335,62},{250,146},{273,99}}) do
        local covered=false
        for _,r in ipairs(panels) do
            if point[1]>=r[1] and point[1]<r[1]+r[3] and point[2]>=r[2] and point[2]<r[2]+r[4] then covered=true end
        end
        assert(covered,'original control cropped out')
    end
end end
print('PASS: LCD bounds, uniform panel scaling, original controls in both game sizes')
