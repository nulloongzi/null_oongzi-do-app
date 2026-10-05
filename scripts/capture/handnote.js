// scripts/capture/handnote.js — 손글씨 주석 카드의 마커·형광펜 그리기(make_cards.py 가 페이지에 싣는다).
// 색연필/마커 질감은 SVG 필터(turbulence+displacement), 동그라미는 끝이 겹치는 두 획.
// make_cards.py 가 붙인 표식을 읽어 그린다:
//   .hl                         제목 키워드 형광펜
//   [data-mark=circle]          누를 곳 동그라미(data-pad, data-seed)
//   [data-mark=word]            빨간 단어("여기!") → 바로 앞 동그라미로 화살표
const NS="http://www.w3.org/2000/svg";
function rng(s){return()=>{s=(s*16807)%2147483647;return(s-1)/2147483646}}
const DEFS=`<defs>
 <filter id="pencil" x="-5%" y="-5%" width="110%" height="110%">
  <feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="2" seed="4" result="w"/>
  <feDisplacementMap in="SourceGraphic" in2="w" scale="5" result="d"/>
  <feTurbulence type="fractalNoise" baseFrequency="1.1" numOctaves="1" seed="9" result="g"/>
  <feColorMatrix in="g" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -2.2 1.75" result="ga"/>
  <feComposite in="d" in2="ga" operator="in"/>
 </filter>
 <filter id="mk" x="-5%" y="-5%" width="110%" height="110%">
  <feTurbulence type="fractalNoise" baseFrequency="0.05" numOctaves="2" seed="7" result="w"/>
  <feDisplacementMap in="SourceGraphic" in2="w" scale="4"/>
 </filter>
 <filter id="marker" x="-5%" y="-20%" width="110%" height="140%">
  <feTurbulence type="fractalNoise" baseFrequency="0.02 0.3" numOctaves="2" seed="2" result="w"/>
  <feDisplacementMap in="SourceGraphic" in2="w" scale="7"/>
 </filter></defs>`;
function layer(slide,cls){const s=document.createElementNS(NS,"svg");s.setAttribute("class","layer "+cls);s.setAttribute("viewBox","0 0 1080 1440");s.innerHTML=DEFS;slide.appendChild(s);return s}
function path(svg,d,attrs){const p=document.createElementNS(NS,"path");p.setAttribute("d",d);for(const k in attrs)p.setAttribute(k,attrs[k]);svg.appendChild(p);return p}
function rect(slide,el){const a=slide.getBoundingClientRect(),b=el.getBoundingClientRect();return{x:b.left-a.left,y:b.top-a.top,w:b.width,h:b.height}}
// open, overshooting marker ellipse (2 strokes -> darker overlap)
const MK={fill:"none",stroke:"var(--red)","stroke-width":15,"stroke-linecap":"round","stroke-linejoin":"round",opacity:.9,filter:"url(#mk)"};
function roughEllipse(svg,r,seed,pad=28,col="var(--red)"){
 const R=rng(seed),cx=r.x+r.w/2,cy=r.y+r.h/2,rx=r.w/2+pad,ry=r.h/2+pad*.8;
 const start=-2.2+R()*.4,sweep=Math.PI*2+.5,ph=R()*6,N=90,pts=[];
 for(let i=0;i<=N;i++){const t=i/N,th=start+sweep*t,k=1+.03*Math.sin(2*th+ph)+.07*t;
  pts.push([cx+rx*k*Math.cos(th),cy+ry*k*Math.sin(th)-t*12])}
 const seg=(a,b)=>pts.slice(a,b+1).map((p,i)=>(i?"L":"M")+p[0].toFixed(1)+" "+p[1].toFixed(1)).join("");
 const cut=Math.round(N*.72);
 path(svg,seg(0,cut),{...MK,stroke:col});path(svg,seg(cut-6,N),{...MK,stroke:col});
}
function roughArrow(svg,x1,y1,x2,y2,bend=.25,col="var(--red)",w=13){
 const mx=(x1+x2)/2,my=(y1+y2)/2,dx=x2-x1,dy=y2-y1,cx=mx-dy*bend,cy=my+dx*bend;
 const st={...MK,stroke:col,"stroke-width":w};
 path(svg,`M${x1} ${y1} Q${cx} ${cy} ${x2} ${y2}`,st);
 const a=Math.atan2(y2-cy,x2-cx),L=46;
 const h=s=>`M${(x2-L*Math.cos(a+s)).toFixed(1)} ${(y2-L*Math.sin(a+s)).toFixed(1)} L${x2} ${y2}`;
 path(svg,h(.5),st);path(svg,h(-.45),st);
}
function highlighter(svg,r,seed,{full=false,op=.62}={}){
 const R=rng(seed),x=r.x-10,w=r.w+20,top=full?r.y+r.h*.12:r.y+r.h*.5,bot=r.y+r.h*.95,tilt=(R()-.5)*8;
 const d=`M${x} ${top+tilt} L${x+w} ${top-tilt+R()*4} L${x+w+4} ${bot-tilt} L${x-3} ${bot+tilt+R()*4}Z`;
 path(svg,d,{fill:"var(--hl)",opacity:op,filter:"url(#marker)"});
}

document.fonts.ready.then(()=>{
 // 제목이 폭 968 을 넘으면 줄인다
 document.querySelectorAll('.title').forEach(t=>{let f=104;while(t.getBoundingClientRect().width>968&&f>60){f-=2;t.style.fontSize=f+'px'}});
 document.querySelectorAll(".slide").forEach(s=>{
  const u=layer(s,"under"),o=layer(s,"over");
  s.querySelectorAll(".hl").forEach(h=>highlighter(u,rect(s,h),+h.dataset.seed||1));
  let last=null;
  s.querySelectorAll("[data-mark]").forEach(el=>{
   if(el.dataset.mark==="circle"){
    last=rect(s,el);roughEllipse(o,last,+el.dataset.seed||1,+el.dataset.pad||20);
   }else if(el.dataset.mark==="word"&&last){
    const q=rect(s,el),r=last,below=r.y>q.y+q.h/2;
    const x1=q.x+q.w*.6,y1=below?q.y+q.h+8:q.y-8;
    const x2=r.x+r.w/2-12,y2=below?r.y-34:r.y+r.h+34;
    roughArrow(o,x1,y1,x2,y2,below?.3:-.3);
   }
  });
 });
 document.body.dataset.ready=1;
});
