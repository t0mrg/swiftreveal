// Render each diagram before capture; generated SVG is the only diagram content.
window.swiftRevealDiagramsReady = (async () => {
  const errors = [];
  const targets = Array.from(document.querySelectorAll('.sr-mermaid[data-source]'));
  if (!targets.length) return errors;
  if (document.fonts) await document.fonts.ready;
  const tags = new Set(['svg','g','defs','marker','path','rect','circle','ellipse','polygon','polyline','line','text','tspan','title','desc','clippath','lineargradient','radialgradient','stop']);
  const attributes = new Set(['id','class','viewbox','xmlns','width','height','x','y','x1','x2','y1','y2','cx','cy','r','rx','ry','d','points','transform','fill','stroke','stroke-width','stroke-dasharray','stroke-dashoffset','opacity','fill-opacity','stroke-opacity','fill-rule','clip-rule','clip-path','marker-start','marker-mid','marker-end','markerwidth','markerheight','refx','refy','orient','markerunits','preserveaspectratio','text-anchor','dominant-baseline','dy','dx','font-weight','offset','stop-color','stop-opacity','gradientunits','gradienttransform','role','aria-labelledby','aria-roledescription','aria-label','focusable']);
  const safeStyleProperties = new Set(['fill','stroke','stroke-width','stroke-dasharray','opacity','fill-opacity','stroke-opacity','color','font-weight','font-style','text-anchor']);
  function safeSVG(markup, fontSize) {
    const parsed = new DOMParser().parseFromString(markup, 'image/svg+xml');
    const root = parsed.documentElement;
    if (root.localName !== 'svg' || parsed.querySelector('parsererror')) throw new Error('The diagram did not produce valid SVG.');
    for (const node of [root, ...root.querySelectorAll('*')]) {
      if (!tags.has(node.localName.toLowerCase())) { node.remove(); continue; }
      for (const attribute of [...node.attributes]) {
        const name = attribute.name.toLowerCase(), value = attribute.value;
        if (name === 'style') {
          const declarations = value.split(';').map(part => {
            const colon = part.indexOf(':');
            return [part.slice(0,colon).trim().toLowerCase(),part.slice(colon+1).trim()];
          }).filter(([property,value]) => safeStyleProperties.has(property) && !/[<>@]|url\s*\(|expression\s*\(|javascript\s*:/i.test(value));
          node.removeAttribute(attribute.name);
          for (const [property,value] of declarations) node.style.setProperty(property,value);
        } else if (!attributes.has(name) || /[<>]|javascript\s*:|data\s*:|https?\s*:/i.test(value) && name !== 'xmlns' || /url\s*\(/i.test(value) && !/^url\(#[A-Za-z0-9_.:-]+\)$/.test(value.trim())) {
          node.removeAttribute(attribute.name);
        }
      }
    }
    root.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
    root.setAttribute('preserveAspectRatio', 'xMidYMid meet');
    root.removeAttribute('width'); root.removeAttribute('height');
    root.style.fontSize = fontSize + 'px';
    return document.importNode(root, true);
  }
  for (let index = 0; index < targets.length; index++) {
    const target = targets[index];
    let scratch;
    try {
      const bytes = Uint8Array.from(atob(target.dataset.source), character => character.charCodeAt(0));
      const source = new TextDecoder().decode(bytes).replace(/\r\n?/g,'\n');
      if (source.length > 50000) throw new Error('Diagrams are limited to 50,000 characters.');
      if (!/^\s*(?:%%[^\n]*\n\s*)*(?:flowchart|graph)\s+(?:TB|TD|BT|LR|RL)\b/.test(source)) throw new Error('Start with flowchart or graph and a direction such as LR or TD.');
      if (/%%\s*\{|^\s*---\s*$/m.test(source)) throw new Error('Diagram configuration directives and front matter are not supported.');
      if (!window.mermaid?.render) throw new Error('The bundled Mermaid renderer is unavailable.');
      const fontSize = Math.max(6, Math.min(352, Number.parseFloat(getComputedStyle(target).fontSize) || 22));
      mermaid.initialize({ startOnLoad:false, securityLevel:'strict', suppressErrorRendering:true,
        maxTextSize:50000, maxEdges:500, theme:'base', fontFamily:'Helvetica Neue, Arial, sans-serif',
        themeVariables:{fontSize:fontSize+'px'},
        flowchart:{htmlLabels:false,useMaxWidth:false,defaultRenderer:'dagre-wrapper'},
        htmlLabels:false, deterministicIds:true, deterministicIDSeed:'swiftreveal-'+index });
      scratch = document.createElement('div');
      scratch.style.cssText='position:fixed;left:-20000px;top:0;width:1152px;height:500px;visibility:hidden;pointer-events:none';
      document.body.appendChild(scratch);
      const rendered = await mermaid.render('sr-diagram-'+index, source, scratch);
      target.replaceChildren(safeSVG(rendered.svg, fontSize));
      target.dataset.rendered='true';
    } catch (error) {
      const detail = String(error?.message || error).slice(0,600);
      const message = 'Mermaid diagram '+(index+1)+': '+detail;
      errors.push(message);
      const warning = document.createElement('div'); warning.className='sr-diagram-error';
      warning.textContent=message; target.replaceChildren(warning); target.dataset.error=message;
    } finally { scratch?.remove(); }
  }
  window.swiftRevealDiagramErrors=errors;
  return errors;
})();
