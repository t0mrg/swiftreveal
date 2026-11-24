// Source for the offline runtime. Regenerate with npm ci && npm run build.
import PptxGenJS from 'pptxgenjs';
import JSZip from 'jszip';
const inch=n=>n/96, pt=n=>n*.75, num=n=>Number.parseFloat(n)||0;
const box=r=>({x:inch(r.x),y:inch(r.y),w:inch(r.w),h:inch(r.h)});
function rgba(s) {
  const v=s.match(/[\d.]+/g)?.map(Number)||[];
  if(!s.startsWith('rgb'))return {color:'FFFFFF',transparency:100};
  return {color:v.slice(0,3).map(n=>Math.round(n).toString(16).padStart(2,'0')).join('').toUpperCase(),transparency:(1-(v[3]??1))*100};
}
function fontFamily(css) {
  const f=css.split(',').map(s=>s.trim().replace(/['"]/g,''));
  return f.find(s=>!['-apple-system','BlinkMacSystemFont','system-ui','sans-serif','serif','monospace'].includes(s)) || (f.includes('monospace')?'Menlo':f.includes('serif')?'Georgia':'Helvetica Neue');
}
function textStyle(node) {
  const s=getComputedStyle(node);
  return {fontFace:fontFamily(s.fontFamily),fontSize:pt(num(s.fontSize)),bold:num(s.fontWeight)>=600,italic:s.fontStyle==='italic',...rgba(s.color),
    underline:s.textDecorationLine.includes('underline'),strike:s.textDecorationLine.includes('line-through'),charSpacing:pt(num(s.letterSpacing)),
    subscript:s.verticalAlign==='sub',superscript:s.verticalAlign==='super'};
}
function richRuns(node) {
  const runs=[];
  function visit(n) {
    if(n.nodeType===Node.TEXT_NODE) {
      if(!n.textContent)return;
      const s=getComputedStyle(n.parentElement);let text=n.textContent;
      if(!['pre','pre-wrap','break-spaces','pre-line'].includes(s.whiteSpace))text=text.replace(/[\t\r\n ]+/g,' ');
      if(s.textTransform==='uppercase')text=text.toUpperCase();
      if(s.textTransform==='lowercase')text=text.toLowerCase();
      const options=textStyle(n.parentElement),a=n.parentElement.closest('a[href]');
      if(a&&/^(https?:|mailto:)/i.test(a.getAttribute('href')))options.hyperlink={url:a.getAttribute('href')};
      runs.push({text,options});
    } else if(n.nodeType===Node.ELEMENT_NODE) {
      if(n.tagName==='BR')runs.push({text:'\n',options:textStyle(n)});
      else if(!n.matches('ul,ol,svg,script,style'))Array.from(n.childNodes).forEach(visit);
    }
  }
  Array.from(node.childNodes).forEach(visit);return runs;
}
function styledSVG(svg) {
  const copy=svg.cloneNode(true), originals=[svg,...svg.querySelectorAll('*')],clones=[copy,...copy.querySelectorAll('*')];
  const props=['fill','fill-opacity','stroke','stroke-width','stroke-opacity','stroke-dasharray','stroke-linecap','stroke-linejoin','font-family','font-size','font-weight','font-style','text-anchor','dominant-baseline','opacity','paint-order'];
  originals.forEach((n,i)=>{const s=getComputedStyle(n);props.forEach(p=>{const v=s.getPropertyValue(p);if(v)clones[i].style.setProperty(p,v);});clones[i].style.fontFamily=fontFamily(s.fontFamily);});
  copy.querySelectorAll('style').forEach(n=>n.remove());copy.setAttribute('xmlns','http://www.w3.org/2000/svg');
  const v=svg.viewBox.baseVal;copy.setAttribute('width',String(v.width||svg.clientWidth));copy.setAttribute('height',String(v.height||svg.clientHeight));
  return 'data:image/svg+xml;base64,'+btoa(unescape(encodeURIComponent(new XMLSerializer().serializeToString(copy))));
}
async function capture() {
  if(window.swiftRevealDiagramsReady){const e=await window.swiftRevealDiagramsReady;if(e.length)throw new Error('Cannot export diagram: '+e.join('; '));}
  await window.swiftRevealReady;
  const root=document.querySelector('article.sr-slide'),origin=root.getBoundingClientRect();
  const rect=n=>{const r=n.getBoundingClientRect();return {x:r.left-origin.left,y:r.top-origin.top,w:r.width,h:r.height};};
  const objects=[],placeholders=[],warnings=[...(window.swiftRevealReport?.().warnings||[])];
  const visible=n=>{const s=getComputedStyle(n),r=rect(n);return s.display!=='none'&&s.visibility!=='hidden'&&num(s.opacity)>0&&r.w>0&&r.h>0;};
  function shape(n,name) {
    if(!visible(n))return;
    const s=getComputedStyle(n),fill=rgba(s.backgroundColor),edges=['Top','Right','Bottom','Left'];
    if(fill.transparency<100||edges.some(e=>num(s['border'+e+'Width'])))objects.push({kind:'shape',name,rect:rect(n),fill,radius:num(s.borderTopRightRadius),opacity:num(s.opacity),
      borders:edges.map(e=>({width:num(s['border'+e+'Width']),...rgba(s['border'+e+'Color'])}))});
  }
  function text(n,role) {
    if(!visible(n))return;
    const runs=richRuns(n);if(!runs.some(r=>r.text.trim()))return;
    const s=getComputedStyle(n),r=rect(n),p=[s.paddingTop,s.paddingRight,s.paddingBottom,s.paddingLeft].map(num);
    r.x+=p[3];r.y+=p[0];r.w-=p[1]+p[3];r.h-=p[0]+p[2];
    const bullet=n.tagName==='LI',font=num(s.fontSize),indent=bullet?font*1.1:0;
    r.x-=indent;r.w+=indent;
    objects.push({kind:'text',role,rect:r,runs,options:{...textStyle(n),align:['left','center','right','justify'].includes(s.textAlign)?s.textAlign:'left',
      lineSpacing:pt(num(s.lineHeight)||font*1.2),margin:0,paraSpaceAfter:0,paraSpaceBefore:0,valign:'top',wrap:true,
      ...(bullet?{bullet:n.parentElement.tagName==='OL'?{type:'ul',style:'arabicPeriod',numberStartAt:Array.from(n.parentElement.children).indexOf(n)+1,indent:pt(indent)}:{indent:pt(indent)},hanging:pt(indent*.65)}:{})}});
  }
  function paragraphs(n,role='body') {
    if(!visible(n))return;
    if(n.matches('p,li,pre,blockquote,h1,h2,h3,h4,h5,h6')||!Array.from(n.children).some(c=>['block','list-item','flex','grid'].includes(getComputedStyle(c).display))){
      text(n,role);n.querySelectorAll(':scope > ul,:scope > ol').forEach(c=>Array.from(c.children).forEach(v=>paragraphs(v,role)));
    }else Array.from(n.children).forEach(c=>paragraphs(c,role));
  }
  const rs=getComputedStyle(root),gradient=rs.backgroundImage.startsWith('linear-gradient(')?rs.backgroundImage:null;
  objects.push({kind:'shape',name:'Canvas background',rect:{x:0,y:0,w:origin.width,h:origin.height},fill:rgba(rs.backgroundColor),radius:0,borders:[],gradient,gradientColors:gradient?.match(/rgba?\([^)]+\)/g)?.map(rgba)});
  const bg=root.querySelector('.sr-background-image');
  if(bg){
    if(!bg.naturalWidth)throw new Error('The background image could not be decoded.');
    objects.push({kind:'image',rect:rect(bg),data:bg.src,fit:getComputedStyle(bg).objectFit,naturalW:bg.naturalWidth,naturalH:bg.naturalHeight,name:'Background image'});
    shape(root.querySelector('.sr-background-overlay'),'Translucent background overlay');
  }
  function placeholder(n,role,type='body',region=null,extra={}){
    if(!n||!visible(n))return;
    const s=getComputedStyle(n);placeholders.push({role,type,rect:region||rect(n),options:{...textStyle(n),align:s.textAlign==='center'?'center':'left',margin:0,valign:'top',lineSpacing:pt(num(s.lineHeight)),...extra}});
  }
  root.querySelectorAll('.sr-kicker,h1,.sr-subtitle').forEach(n=>{const role=n.matches('h1')?'title':n.matches('.sr-subtitle')?'subtitle':'kicker';text(n,role);placeholder(n,role,role==='title'?'title':'body');});
  for(const block of root.querySelectorAll('[data-block-id]')){
    if(!visible(block))continue;
    shape(block,'Block panel');
    const heading=block.querySelector('.sr-heading');if(heading){text(heading,'heading');placeholder(heading,'heading');}
    const copy=block.querySelector('.sr-copy');if(copy){
      paragraphs(copy);const r=rect(copy),b=rect(block),s=getComputedStyle(block),caption=block.querySelector('.sr-caption');
      r.h=Math.max(r.h,(caption?rect(caption).y-12:b.y+b.h-num(s.paddingBottom))-r.y);
      if(s.justifyContent==='center'){r.y=b.y+num(s.paddingTop);r.h=b.h-num(s.paddingTop)-num(s.paddingBottom);}
      placeholder(copy,'body','body',r,s.justifyContent==='center'?{valign:'mid'}:{});
    }
    placeholder(block.querySelector('.sr-image-area'),'picture','pic');
    const img=block.querySelector('.sr-image-area img');
    if(img){if(!img.naturalWidth)throw new Error('A figure image could not be decoded.');objects.push({kind:'image',rect:rect(img),data:img.src,fit:getComputedStyle(img).objectFit,naturalW:img.naturalWidth,naturalH:img.naturalHeight,name:'Figure'});}
    const emptyFigure=block.querySelector('.sr-placeholder');if(emptyFigure){shape(emptyFigure,'Figure placeholder');Array.from(emptyFigure.children).forEach(n=>text(n,'picture'));}
    const svg=block.querySelector('.sr-mermaid svg');if(svg){const v=svg.viewBox.baseVal;objects.push({kind:'image',name:'Mermaid SVG diagram',rect:rect(svg),data:styledSVG(svg),fit:'contain',naturalW:v.width,naturalH:v.height});}
    const table=block.querySelector('table');
    if(table){placeholder(table,'table','body');const rows=Array.from(table.rows);objects.push({kind:'table',rect:rect(table),colW:Array.from(rows[0]?.cells||[]).map(c=>inch(rect(c).w)),rowH:rows.map(r=>inch(rect(r).h)),
      rows:rows.map(row=>Array.from(row.cells).map(cell=>{const s=getComputedStyle(cell),bg=rgba(s.backgroundColor),rowBG=rgba(getComputedStyle(row).backgroundColor);return {text:richRuns(cell),options:{...textStyle(cell),align:s.textAlign,valign:'top',
        margin:[s.paddingTop,s.paddingRight,s.paddingBottom,s.paddingLeft].map(v=>pt(num(v))),fill:bg.transparency<100?bg:rowBG,
        border:[{type:'solid',color:'FFFFFF',pt:0},{type:'solid',color:'FFFFFF',pt:0},{type:'solid',color:rgba(s.borderBottomColor).color,pt:pt(num(s.borderBottomWidth))},{type:'solid',color:'FFFFFF',pt:0}]}};}))});}
    const caption=block.querySelector('.sr-caption');if(caption){text(caption,'caption');placeholder(caption,'caption');}
  }
  root.querySelectorAll('.sr-footer span').forEach(n=>text(n,'footer'));
  const bad=document.querySelector('[data-image-warning]');if(bad)throw new Error(bad.dataset.imageWarning);
  if(Array.from(root.querySelectorAll('*')).some(n=>{const s=getComputedStyle(n);return !n.closest('svg')&&(s.transform!=='none'||s.filter!=='none'||s.boxShadow!=='none'||s.textShadow!=='none');}))warnings.push('CSS transforms, filters and shadows may differ in PowerPoint.');
  return JSON.stringify({objects,placeholders,warnings,width:origin.width,height:origin.height});
}
function shapeDefs(o){
  const fill={...o.fill,transparency:100-(100-o.fill.transparency)*(o.opacity??1)},r=box(o.rect),edge=o.borders?.[0];
  const uniform=o.borders?.length===4&&o.borders.every(b=>JSON.stringify(b)===JSON.stringify(edge));
  const defs=[{...r,rectRadius:inch(o.radius),objectName:o.name,fill,line:uniform&&edge.width?{color:edge.color,transparency:edge.transparency,width:pt(edge.width)}:{transparency:100}}];
  if(!uniform)(o.borders||[]).forEach((b,i)=>{if(!b.width)return;const horizontal=i%2===0;defs.push({x:r.x+(i===1?r.w-inch(b.width):0),y:r.y+(i===2?r.h-inch(b.width):0),w:horizontal?r.w:inch(b.width),h:horizontal?inch(b.width):r.h,fill:{color:b.color,transparency:b.transparency},line:{transparency:100},objectName:'Panel border'});});
  return defs;
}
function imageOptions(ppt,o){
  const r=box(o.rect),ratio=o.naturalW/o.naturalH;let dims;
  if(o.fit==='cover')dims={x:r.x,y:r.y,w:inch(o.naturalW),h:inch(o.naturalH),sizing:{type:'cover',w:r.w,h:r.h}};
  else if(o.fit==='fill')dims=r;
  else{const w=Math.min(r.w,r.h*ratio),h=w/ratio;dims={x:r.x+(r.w-w)/2,y:r.y+(r.h-h)/2,w,h};}
  return {data:o.data,...dims,objectName:o.name,altText:o.name};
}
function addObject(target,ppt,o){
  if(o.kind==='shape')shapeDefs(o).forEach((d,i)=>target.addShape(o.radius&&i===0?ppt.ShapeType.roundRect:ppt.ShapeType.rect,d));
  if(o.kind==='text')target.addText(o.runs,{...o.options,...box(o.rect),objectName:`SwiftReveal ${o.role}`});
  if(o.kind==='image')target.addImage(imageOptions(ppt,o));
  if(o.kind==='table')target.addTable(o.rows,{...box(o.rect),colW:o.colW,rowH:o.rowH,autoPage:false,margin:0,border:{type:'solid',color:'FFFFFF',pt:0},objectName:'Editable table'});
}
async function write(payloadJSON){
  const payload=JSON.parse(payloadJSON),ppt=new PptxGenJS();
  ppt.defineLayout({name:'SwiftReveal',width:inch(payload.width),height:inch(payload.height)});ppt.layout='SwiftReveal';
  ppt.title=payload.title;ppt.author=payload.author;ppt.subject='SwiftReveal editable presentation';ppt.company='';ppt.lang='en-GB';ppt.theme={headFontFace:'Helvetica Neue',bodyFontFace:'Helvetica Neue',lang:'en-GB'};
  const names=new Map();
  for(const master of payload.masters){
    const name=`SwiftReveal · ${master.label}`;names.set(master.layout,name);const objects=[];
    for(const o of master.snapshot.objects)if(o.kind==='shape')shapeDefs(o).forEach(d=>objects.push({rect:d}));
    for(const [i,o] of master.snapshot.placeholders.entries())objects.push({placeholder:{text:'Click to add '+o.role,
      options:{...o.options,...box(o.rect),objectName:`SwiftReveal ${o.role} ${i+1}`,name:`${master.layout}-${o.role}-${i}`,type:o.type}}});
    const footers=master.snapshot.objects.filter(o=>o.kind==='text'&&o.role==='footer');
    const footer=footers.find(o=>!/^\d+ \/ \d+$/.test(o.runs.map(r=>r.text).join('')));
    if(footer)objects.push({text:{text:payload.footer,options:{...footer.options,...box(footer.rect)}}});
    const number=footers.find(o=>/^\d+ \/ \d+$/.test(o.runs.map(r=>r.text).join('')));
    ppt.defineSlideMaster({title:name,background:{color:'FFFFFF'},objects,...(number?{slideNumber:{...number.options,...box(number.rect),align:'right'}}:{})});
  }
  for(const entry of payload.slides){const slide=ppt.addSlide({masterName:names.get(entry.layout)});entry.snapshot.objects.forEach(o=>addObject(slide,ppt,o));if(entry.notes)slide.addNotes(entry.notes);}
  const raw=await ppt.write({outputType:'base64',compression:true}),zip=await JSZip.loadAsync(raw,{base64:true});
  const ns='http://schemas.openxmlformats.org/presentationml/2006/main',a='http://schemas.openxmlformats.org/drawingml/2006/main';
  function gradientXML(xml,snapshot){
    const doc=new DOMParser().parseFromString(xml,'application/xml'),gradient=snapshot.objects.find(o=>o.gradientColors?.length>=2);
    if(gradient){
      const shape=Array.from(doc.getElementsByTagNameNS(ns,'sp')).find(s=>s.getElementsByTagNameNS(ns,'cNvPr')[0]?.getAttribute('name')==='Canvas background'),props=shape?.getElementsByTagNameNS(ns,'spPr')[0];
      if(props){
        Array.from(props.children).filter(c=>['solidFill','noFill'].includes(c.localName)).forEach(c=>c.remove());
        const colors=gradient.gradientColors,m=gradient.gradient.match(/([\d.]+)deg/),angle=((((m?Number(m[1]):180)-90)%360+360)%360)*60000;
        const fragment=new DOMParser().parseFromString(`<a:gradFill xmlns:a="${a}" rotWithShape="1"><a:gsLst>${colors.map((c,i)=>`<a:gs pos="${Math.round(i*100000/(colors.length-1))}"><a:srgbClr val="${c.color}"><a:alpha val="${Math.round((100-c.transparency)*1000)}"/></a:srgbClr></a:gs>`).join('')}</a:gsLst><a:lin ang="${angle}" scaled="1"/></a:gradFill>`,'application/xml');
        props.insertBefore(doc.importNode(fragment.documentElement,true),Array.from(props.children).find(c=>['ln','effectLst','effectDag','scene3d','sp3d','extLst'].includes(c.localName))||null);
      }
    }
    // PptxGenJS 4 emits repeated pPr elements for rich runs. OOXML permits one
    // paragraph-properties node; later copies can suppress a native list marker.
    Array.from(doc.getElementsByTagNameNS(a,'p')).forEach(p=>{
      const props=Array.from(p.children).filter(n=>n.localName==='pPr');
      props.slice(1).forEach(n=>n.remove());
    });
    return doc;
  }
  for(let i=0;i<payload.slides.length;i++){
    const path=`ppt/slides/slide${i+1}.xml`,doc=gradientXML(await zip.file(path).async('string'),payload.slides[i].snapshot);
    // Measured slide objects cover the layout design. Remove the empty placeholders
    // automatically cloned by PptxGenJS; new slides still inherit the real placeholders.
    Array.from(doc.getElementsByTagNameNS(ns,'sp')).filter(s=>s.getElementsByTagNameNS(ns,'ph').length).forEach(s=>s.remove());
    zip.file(path,new XMLSerializer().serializeToString(doc));
  }
  for(let i=0;i<payload.masters.length;i++){
    const path=`ppt/slideLayouts/slideLayout${i+2}.xml`,file=zip.file(path);
    if(file){
      const doc=gradientXML(await file.async('string'),payload.masters[i].snapshot);
      // The library's placeholder enum omits pic/tbl after a second lookup.
      // Write explicit OOXML types so Office offers picture insertion, not text.
      Array.from(doc.getElementsByTagNameNS(ns,'ph')).filter(p=>p.getAttribute('type')!=='sldNum').forEach((ph,j)=>{
        const region=payload.masters[i].snapshot.placeholders[j];
        if(region){
          ph.setAttribute('type',region.role==='table'?'obj':region.type);
          const shape=ph.parentElement?.parentElement?.parentElement,body=shape?.getElementsByTagNameNS(a,'bodyPr')[0];
          if(body)body.setAttribute('anchor',region.options.valign==='mid'?'ctr':'t');
        }
      });
      zip.file(path,new XMLSerializer().serializeToString(doc));
    }
  }
  for(const path of Object.keys(zip.files).filter(p=>/^ppt\/theme\/theme\d+\.xml$/.test(p))){
    const doc=new DOMParser().parseFromString(await zip.file(path).async('string'),'application/xml');
    const scheme=doc.getElementsByTagNameNS(a,'clrScheme')[0];
    if(scheme)for(const node of scheme.children){
      const color=payload.colors?.[node.localName];if(!color)continue;
      while(node.firstChild)node.firstChild.remove();
      const rgb=doc.createElementNS(a,'a:srgbClr');rgb.setAttribute('val',color);node.appendChild(rgb);
    }
    zip.file(path,new XMLSerializer().serializeToString(doc));
  }
  return zip.generateAsync({type:'base64',compression:'DEFLATE'});
}
window.swiftRevealPowerPoint={capture,write};
