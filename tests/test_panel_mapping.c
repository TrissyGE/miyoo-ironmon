/* Compile on the host: cc tests/test_panel_mapping.c -o /tmp/panel-test */
#include <assert.h>
#include <stdio.h>
#include "../panel_layout.h"
int main(void){
    struct panel_region stats={341,5,45,76,518,110,116,196};
    int x,y;
    assert(panel_point(&stats,518,110,&x,&y)&&x==341&&y==5);
    assert(panel_point(&stats,633,305,&x,&y)&&x==385&&y==80);
    assert(!panel_point(&stats,634,305,&x,&y));
    assert(!panel_point(&stats,633,306,&x,&y));
    assert(!panel_point(&stats,517,110,&x,&y));
    /* All points in a stat-mark button reach that original button after scaling. */
    for(int py=121;py<131;py++)for(int px=593;px<606;px++){
        assert(panel_point(&stats,px,py,&x,&y));
        assert(x>=369&&x<377&&y>=9&&y<17);
    }
    struct panel_region regions[]={
        {0,0,240,160,0,0,512,342},
        {240,0,150,160,91,20,330,352},
        {0,0,390,160,0,96,640,263}
    };
    assert(panel_pick(regions,2,100,30,&x,&y)&&x>=240); /* details cover game */
    assert(panel_pick(regions,3,100,120,&x,&y)&&x<240); /* form covers details */
    assert(!panel_pick(regions,3,639,479,&x,&y)&&x==-1&&y==-1);
    puts("PASS: panel boundaries, stat buttons, popup priority and empty margins");
}
