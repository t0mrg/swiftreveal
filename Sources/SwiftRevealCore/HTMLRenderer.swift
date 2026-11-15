import Foundation
import CryptoKit

/// One renderer is shared by editing, presentation, HTML export and PDF capture.
/// User-authored markup is reconstructed by an allowlist sanitizer; scripts remain trusted-only.
public enum HTMLRenderer {
    private enum Mode { case preview, presentation, singleSlide }

    public static func preview(deck: Deck, slideIndex: Int) -> String {
        document(deck: deck, mode: .preview, index: slideIndex)
    }
    public static func presentation(deck: Deck, startIndex: Int = 0) -> String {
        document(deck: deck, mode: .presentation, index: startIndex)
    }
    public static func export(deck: Deck) -> String {
        presentation(deck: deck)
    }
    /// Capture this document at a 1280 × 720 WebKit viewport without scaling.
    public static func singleSlide(deck: Deck, slideIndex: Int) -> String {
        document(deck: deck, mode: .singleSlide, index: slideIndex)
    }

    private static func document(deck: Deck, mode: Mode, index: Int) -> String {
        let index = max(0, min(index, max(0, deck.slides.count - 1)))
        let isPresentation = mode == .presentation
        let revealCSS = isPresentation ? resource("reveal", extension: "css") : ""
        let revealJS = isPresentation ? resource("reveal", extension: "js") : ""
        let license = isPresentation ? "<!-- reveal.js license\n\(resource("reveal-LICENSE", extension: "").replacingOccurrences(of: "--", with: "- -"))\n-->" : ""
        let selectedSlides = isPresentation ? Array(deck.slides.enumerated()) : deck.slides.indices.contains(index) ? [(index, deck.slides[index])] : []
        let hasDiagrams = selectedSlides.contains { $0.1.blocks.contains { $0.kind == .mermaid } }
        let mermaidJS = hasDiagrams ? resource("mermaid.min", extension: "js") : ""
        let diagramScript = resource("mermaid-runtime", extension: "js")
        let mermaidLicense = hasDiagrams ? "<!-- Mermaid and bundled dependency licenses\n" + (resource("mermaid-LICENSE", extension: "") + "\n" + resource("mermaid-THIRD-PARTY-NOTICES", extension: "")).replacingOccurrences(of: "--", with: "- -") + "\n-->" : ""
        let slides = selectedSlides.map { number, slide in
            let markup = render(slide: slide, deck: deck, index: number)
            return isPresentation ? "<section>\(markup)<aside class=\"notes\">\(RichText.body(slide.notes))</aside></section>" : markup
        }.joined(separator: "\n")
        let wrap = isPresentation ? "<div class=\"reveal\"><div class=\"slides\">\(slides)</div></div>" : "<main id=\"stage\">\(slides)</main>"
        let modeName = isPresentation ? "presentation" : mode == .preview ? "preview" : "capture"
        let startup: String
        if isPresentation {
            startup = """
            const deck = new Reveal(document.querySelector('.reveal'), {
              width:1280,height:720,margin:0.025,minScale:0.05,maxScale:4,center:false,
              hash:true,transition:'none',controls:true,progress:true,help:true,
              slideNumber:false,embedded:false,view:'slide',scrollActivationWidth:null,
              pdfMaxPagesPerSlide:1,pdfSeparateFragments:false,showNotes:false
            });
            window.swiftRevealDeck = deck;
            deck.initialize().then(() => { if (!location.hash || location.hash === '#/') deck.slide(\(index)); });
            const notes = document.createElement('div'); notes.id='presenter-notes'; document.body.appendChild(notes);
            function updateNotes() { notes.innerHTML = deck.getCurrentSlide()?.querySelector('aside.notes')?.innerHTML || '<p>No speaker notes for this slide.</p>'; }
            deck.on('slidechanged',updateNotes); deck.on('ready',updateNotes);
            document.addEventListener('keydown',event => {
              if (['n','s'].includes(event.key.toLowerCase())) { updateNotes(); notes.classList.toggle('visible'); event.preventDefault(); }
            });
            """
        } else if mode == .preview {
            startup = """
            function fitPreview(){const stage=document.getElementById('stage'); const scale=Math.min(innerWidth/1280,innerHeight/720); stage.style.transform='translate(-50%,-50%) scale('+scale+')';}
            addEventListener('resize',fitPreview); fitPreview();
            document.querySelectorAll('[data-block-id]').forEach(block=>block.addEventListener('click',()=>{
              window.webkit?.messageHandlers?.selectedBlock?.postMessage(block.dataset.blockId);
            }));
            """
        } else { startup = "" }
        let runtimeScript = """
        \(diagramScript)
        \(startup)
        window.swiftRevealReport = function() {
          const warnings=[...(window.swiftRevealDiagramErrors || [])];
          const slide=document.querySelector('.sr-slide');
          if(slide){
            const header=slide.querySelector('.sr-header');
            if(header && (header.scrollWidth>header.clientWidth+2 || header.offsetHeight>300)) warnings.push('The slide heading is too large for this layout. Shorten it or split the slide.');
            const backgroundImage=slide.querySelector('.sr-background-image');
            if(backgroundImage && (!backgroundImage.complete || backgroundImage.naturalWidth===0)) warnings.push('The slide background image could not be displayed.');
            const content=slide.querySelector('.sr-content');
            if(content && slide.querySelector('[data-block-id]') && (content.scrollHeight>content.clientHeight+2 || content.scrollWidth>content.clientWidth+2 || content.clientHeight<40)) warnings.push('The slide has more content than its layout can hold. Try Compact spacing or split the slide.');
            slide.querySelectorAll('[data-block-id]').forEach((block,i)=>{
              const rect=block.getBoundingClientRect();
              const overflowing=block.scrollHeight>block.clientHeight+2 || block.scrollWidth>block.clientWidth+2 || Array.from(block.querySelectorAll('table,.sr-image-area,.sr-copy,.sr-heading,.sr-caption')).some(node=>{
                const n=node.getBoundingClientRect(); return n.bottom>rect.bottom+2 || n.right>rect.right+2 || node.scrollWidth>node.clientWidth+2 || node.scrollHeight>node.clientHeight+2;
              });
              if(overflowing) warnings.push('Block '+(i+1)+' does not fit. Shorten its content, change layout, or move it to another slide.');
              const image=block.querySelector('img');
              if(image && (!image.complete || image.naturalWidth===0)) warnings.push('The image in block '+(i+1)+' could not be displayed.');
            });
          }
          const report={slideIndex:\(index),warnings:[...new Set(warnings)],generation:window.swiftRevealGeneration ?? null};
          window.webkit?.messageHandlers?.layoutReport?.postMessage(report); return report;
        };
        // Measure the unscaled typography first, including user CSS, then apply
        // both scope factors to the measured values. Capture every value before
        // mutating any font size so nested em/percent text cannot compound twice.
        window.swiftRevealApplyFontScaling = function() {
          document.querySelectorAll('article.sr-slide[data-slide-index]').forEach(slide => {
            if(slide.dataset.fontScalingApplied === 'true') return;
            const blocks=Array.from(slide.querySelectorAll('[data-block-id]'));
            const factor=(node,name)=>{
              const value=Number.parseFloat(node.style.getPropertyValue(name));
              return Number.isFinite(value) ? Math.min(4,Math.max(.25,value)) : 1;
            };
            const slideFactor=factor(slide,'--slide-font-scale');
            const blockFactors=new Map(blocks.map(block=>[block,factor(block,'--block-font-scale')]));
            if(slideFactor===1 && Array.from(blockFactors.values()).every(value=>value===1)) return;
            const saved=[];
            const reset=(node,name)=>{
              saved.push([node,name,node.style.getPropertyValue(name),node.style.getPropertyPriority(name)]);
              node.style.setProperty(name,'1','important');
            };
            reset(slide,'--slide-font-scale'); reset(slide,'--block-font-scale');
            blocks.forEach(block=>reset(block,'--block-font-scale'));
            let measured=[];
            try {
              measured=[slide,...slide.querySelectorAll('*')].map(node=>{
                if(node.closest('svg')) return null;
                const pixels=Number.parseFloat(getComputedStyle(node).fontSize);
                const block=node.closest('[data-block-id]');
                return [node,pixels,slideFactor*(blockFactors.get(block) ?? 1)];
              }).filter(Boolean);
            } finally {
              saved.forEach(([node,name,value,priority])=>{
                if(value) node.style.setProperty(name,value,priority);
                else node.style.removeProperty(name);
              });
            }
            measured.forEach(([node,pixels,scale])=>{
              if(Number.isFinite(pixels)) node.style.setProperty('font-size',(pixels*scale)+'px','important');
            });
            slide.dataset.fontScalingApplied='true';
          });
        };
        window.swiftRevealReady = (async()=>{
          await window.swiftRevealDiagramsReady;
          if(document.fonts) await document.fonts.ready;
          window.swiftRevealApplyFontScaling();
          await Promise.all(Array.from(document.images).map(img=>img.decode ? img.decode().catch(()=>{}) : Promise.resolve()));
          await new Promise(resolve=>{const fallback=setTimeout(resolve,150);requestAnimationFrame(()=>requestAnimationFrame(()=>{clearTimeout(fallback);resolve();}));});
          return window.swiftRevealReport();
        })();
        """
        let scriptPolicy = ([revealJS, runtimeScript] + (hasDiagrams ? [mermaidJS] : [])).map { "'sha256-" + Data(SHA256.hash(data: Data($0.utf8))).base64EncodedString() + "'" }.joined(separator: " ")
        return """
        <!doctype html>
        <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src \(scriptPolicy); style-src 'unsafe-inline'; img-src data:; font-src data:; connect-src 'none'; object-src 'none'; base-uri 'none'">
        <title>\(escape(deck.title))</title>
        \(license)
        \(mermaidLicense)
        <meta name="author" content="\(escape(deck.author))">
        <meta name="generator" content="SwiftReveal 0.5">
        <style>\(revealCSS)\n\(themeCSS(deck.theme.palette))\n\(css)\n\(safeCSS(deck.customCSS ?? ""))</style></head>
        <body class="sr-\(modeName) theme-\(deck.theme.rawValue)">\(wrap)
        <script>\(revealJS)</script>
        \(hasDiagrams ? "<script>" + mermaidJS + "</script>" : "")
        <script>\(runtimeScript)</script></body></html>
        """
    }

    private static func render(slide: Slide, deck: Deck, index: Int) -> String {
        let split = max(0.25, min(0.75, slide.split.isFinite ? slide.split : 0.5))
        let columns = (slide.layout == .cards || slide.layout == .twoColumns || slide.layout == .figureAndText) ? min(2, max(1, slide.blocks.count)) : slide.layout == .metrics ? min(4, max(1, slide.blocks.count)) : 1
        let rows = max(1, Int(ceil(Double(slide.blocks.count) / Double(columns))))
        let grid = columns == 2 && (slide.layout == .twoColumns || slide.layout == .figureAndText) ? "\(split)fr \(1-split)fr" : "repeat(\(columns),minmax(0,1fr))"
        let background = backgroundMarkup(slide.background)
        let titleOnly = slide.layout == .title && slide.blocks.isEmpty
        let titleClasses = titleOnly ? " title-only" + (slide.centerTitleHorizontally == true ? " title-center-horizontal" : "") + (slide.centerTitleVertically == true ? " title-center-vertical" : "") : ""
        return """
        <article class="sr-slide \(background.isEmpty ? "" : "has-background ")layout-\(slide.layout.rawValue) density-\(slide.density.rawValue)\(titleClasses)" data-slide-index="\(index)" style="--columns:\(grid);--rows:\(rows);--slide-font-scale:\(FontScaling.effective(slide.fontScale));--block-font-scale:1;\(backgroundTextStyle(slide.background))">
        \(background)
          <header class="sr-header">
            \(slide.kicker.isEmpty ? "" : "<div class=\"sr-kicker\">\(RichText.inline(slide.kicker))</div>")
            <h1>\(RichText.inline(slide.title))</h1>
            \(slide.subtitle.isEmpty ? "" : "<p class=\"sr-subtitle\">\(RichText.inline(slide.subtitle))</p>")
          </header>
          <div class="sr-content">\(slide.blocks.enumerated().map { block($0.element, number: $0.offset + 1) }.joined(separator: "\n"))</div>
          <footer class="sr-footer"><span>\(RichText.inline(deck.footer))</span><span>\(index+1) / \(deck.slides.count)</span></footer>
        </article>
        """
    }

    private static func block(_ block: ContentBlock, number: Int) -> String {
        let heading = block.heading.isEmpty ? "" : "<h2 class=\"sr-heading\">\(RichText.inline(block.heading))</h2>"
        let caption = block.caption.isEmpty ? "" : "<div class=\"sr-caption\">\(RichText.inline(block.caption))</div>"
        let copy = block.body.isEmpty ? "" : "<div class=\"sr-copy\">\(RichText.body(block.body))</div>"
        let contents: String
        switch block.kind {
        case .text, .callout, .metric:
            contents = heading + copy + caption
        case .figure:
            let image: String
            if let data = block.imageData, !data.isEmpty, ["image/png", "image/jpeg", "image/gif", "image/webp", "image/tiff"].contains(block.imageMIME) {
                image = "<img alt=\"\(escape(block.caption.isEmpty ? block.heading : block.caption))\" src=\"data:\(block.imageMIME);base64,\(data.base64EncodedString())\" style=\"object-fit:\(block.imageFit ? "contain" : "cover")\">"
            } else {
                image = "<div class=\"sr-placeholder\"><span>Figure</span><small>Choose an image in the content inspector</small></div>"
            }
            contents = heading + "<div class=\"sr-image-area\">\(image)</div>" + copy + caption
        case .mermaid:
            let source = Data(block.body.utf8).base64EncodedString()
            contents = heading + "<div class=\"sr-mermaid\" data-source=\"\(source)\" role=\"img\" aria-label=\"\(escape(block.heading.isEmpty ? "Mermaid diagram" : block.heading))\"></div>" + caption
        case .table:
            let count = max(block.table.headers.count, block.table.rows.map(\.count).max() ?? 0)
            let header = (0..<count).map { "<th scope=\"col\">\(RichText.inline($0 < block.table.headers.count ? block.table.headers[$0] : ""))</th>" }.joined()
            let rows = block.table.rows.map { row in "<tr>" + (0..<count).map { "<td>\(RichText.inline($0 < row.count ? row[$0] : ""))</td>" }.joined() + "</tr>" }.joined()
            contents = heading + copy + "<table><thead><tr>\(header)</tr></thead><tbody>\(rows)</tbody></table>" + caption
        }
        let appearance = blockAppearance(block.style)
        return "<div class=\"sr-block block-\(block.kind.rawValue)\(appearance.classes)\" data-block-id=\"\(block.id.uuidString)\" aria-label=\"Block \(number)\" style=\"\(appearance.style);--block-font-scale:\(FontScaling.effective(block.fontScale))\">\(contents)</div>"
    }

    static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&#39;")
    }

    /// A style element is an HTML raw-text context: escape every '<' so even a
    /// comment or string containing </style> cannot introduce executable markup.
    static func safeCSS(_ value: String) -> String {
        value.replacingOccurrences(of: "<", with: "\\3C ")
    }

    private static func resource(_ name: String, extension ext: String) -> String {
        guard let url = CoreResources.url(name, extension: ext), let value = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return value
    }

    private static let rasterTypes = ["image/png", "image/jpeg", "image/gif", "image/webp", "image/tiff"]

    private static func themeCSS(_ palette: ThemePalette) -> String {
        let values = [("surface",palette.surface),("ink",palette.ink),("secondary",palette.secondary),
                      ("muted",palette.muted),("rule",palette.rule),("tint",palette.tint),("accent",palette.accent),
                      ("deep",palette.deep),("wash",palette.wash),("cover",palette.cover),("cover2",palette.cover2)]
        return ":root{" + values.map { "--\($0.0):\($0.1)" }.joined(separator: ";") + "}"
    }

    private static func blockAppearance(_ style: BlockStyle?) -> (classes: String, style: String) {
        guard let style else { return ("", "") }
        let properties = [("bg",style.background),("fg",style.foreground),("accent",style.accent),
                          ("header-bg",style.headerBackground),("header-fg",style.headerForeground)]
        var classes = "", declarations: [String] = []
        for (name, value) in properties {
            if let color = HexColor.normalized(value) {
                classes += " custom-" + name
                declarations.append("--block-\(name):\(color)")
            }
        }
        return (classes, declarations.joined(separator: ";"))
    }

    private static func usableBackground(_ background: SlideBackground?) -> SlideBackground? {
        guard let background, !background.imageData.isEmpty, rasterTypes.contains(background.imageMIME) else { return nil }
        return background
    }

    private static func backgroundTextStyle(_ background: SlideBackground?) -> String {
        guard let background = usableBackground(background) else { return "" }
        return "--slide-text:" + (HexColor.normalized(background.textColor) ?? "#FFFFFF")
    }

    private static func backgroundMarkup(_ background: SlideBackground?) -> String {
        guard let background = usableBackground(background) else { return "" }
        let color = HexColor.normalized(background.overlayColor) ?? "#102036"
        let opacity = background.overlayOpacity.isFinite ? max(0, min(1, background.overlayOpacity)) : 0.45
        return """
        <div class="sr-background-layer" aria-hidden="true"><img class="sr-background-image" alt="" src="data:\(background.imageMIME);base64,\(background.imageData.base64EncodedString())" style="object-fit:\(background.imageFit ? "contain" : "cover")"><div class="sr-background-overlay" style="background:\(color);opacity:\(opacity)"></div></div>
        """
    }

    private static let css = """
    *{box-sizing:border-box}html,body{margin:0;padding:0;width:100%;height:100%;background:#20242b;color:var(--ink);font-family:-apple-system,BlinkMacSystemFont,"Helvetica Neue",Arial,sans-serif;-webkit-font-smoothing:antialiased}
    body.sr-preview,body.sr-capture{overflow:hidden}#stage{width:1280px;height:720px}.sr-preview #stage{position:absolute;top:50%;left:50%;transform-origin:center center}.sr-capture,.sr-capture #stage{width:1280px;height:720px;background:var(--surface)}
    .sr-slide{position:relative;display:flex;flex-direction:column;width:1280px;height:720px;padding:48px 64px 58px;background:var(--surface);color:var(--ink);text-align:left;overflow:hidden;font-size:calc(25px * var(--slide-font-scale,1) * var(--block-font-scale,1));line-height:1.38;letter-spacing:0;word-wrap:break-word;overflow-wrap:anywhere}
    .sr-slide h1,.sr-slide h2,.sr-slide p,.sr-slide ul,.sr-slide li,.sr-slide table,.sr-slide th,.sr-slide td{margin:0;padding:0;text-align:left;line-height:inherit;font-family:inherit;color:inherit;text-shadow:none;text-transform:none;letter-spacing:0}
    .sr-header{flex:none;margin-bottom:28px}.sr-slide .sr-kicker{font-size:calc(15px * var(--slide-font-scale,1) * var(--block-font-scale,1));font-weight:750;letter-spacing:1.7px;text-transform:uppercase;color:var(--accent);margin-bottom:9px}.sr-slide h1{font-size:calc(39px * var(--slide-font-scale,1) * var(--block-font-scale,1));font-weight:730;line-height:1.14;letter-spacing:-.8px;margin:0;white-space:pre-line}.sr-slide .sr-subtitle{font-size:calc(24px * var(--slide-font-scale,1) * var(--block-font-scale,1));line-height:1.35;color:var(--secondary);margin:14px 0 0;white-space:pre-line}
    .sr-content{display:grid;grid-template-columns:var(--columns);grid-template-rows:repeat(var(--rows),minmax(0,1fr));gap:26px 36px;flex:1;min-height:0;min-width:0;align-items:stretch}
    .sr-block{font-size:calc(var(--body-font-size,25px) * var(--slide-font-scale,1) * var(--block-font-scale,1));min-width:0;min-height:0;display:flex;flex-direction:column;gap:12px;position:relative;overflow:hidden}.sr-block .sr-heading{font-size:calc(26px * var(--slide-font-scale,1) * var(--block-font-scale,1));font-weight:700;line-height:1.22;letter-spacing:-.35px;flex:none}.sr-copy{flex:none;min-width:0}.sr-copy p+p{margin-top:15px}.sr-copy ul{padding-left:26px;margin:0}.sr-copy li{padding-left:3px;margin:0 0 13px}.sr-copy strong{font-weight:730}.sr-caption{flex:none;font-size:calc(16px * var(--slide-font-scale,1) * var(--block-font-scale,1));line-height:1.4;color:var(--muted);margin-top:auto;padding-top:3px;white-space:pre-line}
    .block-callout{padding:23px 25px;background:var(--wash);border-left:5px solid var(--accent);border-radius:0 11px 11px 0;font-size:calc(23px * var(--slide-font-scale,1) * var(--block-font-scale,1))}.block-callout .sr-heading{color:var(--deep);font-size:calc(20px * var(--slide-font-scale,1) * var(--block-font-scale,1));letter-spacing:.4px}.block-metric{padding:27px 28px;background:var(--tint);border-radius:12px}.block-metric .sr-heading{font-size:calc(66px * var(--slide-font-scale,1) * var(--block-font-scale,1));line-height:1.05;letter-spacing:-2px;color:var(--deep)}.block-metric .sr-copy{font-size:calc(24px * var(--slide-font-scale,1) * var(--block-font-scale,1));color:var(--secondary)}
    .block-figure{gap:10px}.sr-image-area{position:relative;flex:1;min-height:70px;min-width:0;display:flex;align-items:center;justify-content:center;overflow:hidden;border-radius:8px}.sr-slide img{display:block;margin:0;padding:0;border:0;box-shadow:none;background:transparent;width:100%;height:100%;max-width:none;max-height:none;position:absolute;inset:0}.sr-placeholder{width:100%;height:100%;min-height:100px;background:var(--tint);border:1.5px dashed #b6c1cf;border-radius:9px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;color:var(--muted)}.sr-placeholder span{font-size:calc(28px * var(--slide-font-scale,1) * var(--block-font-scale,1));font-weight:600}.sr-placeholder small{font-size:calc(17px * var(--slide-font-scale,1) * var(--block-font-scale,1))}
    .sr-slide table{border-collapse:collapse;width:100%;font-size:calc(22px * var(--slide-font-scale,1) * var(--block-font-scale,1));line-height:1.35;table-layout:auto;flex:none}.sr-slide th{font-size:calc(17px * var(--slide-font-scale,1) * var(--block-font-scale,1));font-weight:700;color:var(--secondary);border-bottom:2px solid var(--ink);padding:10px 14px}.sr-slide td{border-bottom:1px solid var(--rule);padding:12px 14px;vertical-align:top}.sr-slide th:first-child,.sr-slide td:first-child{padding-left:0}.sr-slide tbody tr:nth-child(even){background:var(--tint)}.sr-slide td:last-child,.sr-slide th:last-child{padding-right:10px}
    .sr-footer{position:absolute;bottom:20px;left:64px;right:64px;font-size:calc(13px * var(--slide-font-scale,1) * var(--block-font-scale,1));line-height:1.2;color:var(--muted);display:flex;justify-content:space-between;gap:30px;white-space:nowrap}.sr-footer span:first-child{overflow:hidden;text-overflow:ellipsis}
    .layout-title{background:linear-gradient(135deg,var(--cover),var(--cover2));color:#fff;padding-top:75px}.layout-title .sr-kicker{color:#ffffffd9}.layout-title h1{font-size:calc(70px * var(--slide-font-scale,1) * var(--block-font-scale,1));letter-spacing:-2px;line-height:1.07;max-width:1120px}.layout-title .sr-subtitle{color:#ffffffe6;font-size:calc(29px * var(--slide-font-scale,1) * var(--block-font-scale,1));line-height:1.4;max-width:1020px;margin-top:22px}.layout-title .sr-header{margin-bottom:34px}.layout-title .sr-content{max-height:240px;gap:18px}.layout-title .block-callout{background:#ffffff16;border:1px solid #ffffff50;border-left:5px solid #ffffff90;color:#fff;padding:22px 26px}.layout-title .sr-heading,.layout-title .sr-caption{color:#fff}.layout-title .sr-footer{color:#ffffffb3}
    .layout-title.title-only .sr-content{display:none}.layout-title.title-only .sr-header{margin-bottom:0}.layout-title.title-center-vertical{padding-top:58px;justify-content:center}.layout-title.title-center-horizontal .sr-header{text-align:center}.layout-title.title-center-horizontal :is(h1,.sr-subtitle){text-align:center;margin-left:auto;margin-right:auto}
    .block-mermaid{gap:10px}.sr-mermaid{font-size:calc(22px * var(--slide-font-scale,1) * var(--block-font-scale,1));flex:1;min-height:60px;min-width:0;display:flex;align-items:center;justify-content:center;overflow:hidden}.sr-mermaid svg{display:block;width:100%;height:100%;max-width:100%;max-height:100%;overflow:visible}.sr-mermaid svg text{fill:var(--block-fg,var(--ink));font-family:Helvetica Neue,Arial,sans-serif}.sr-mermaid svg :is(.node rect,.node circle,.node ellipse,.node polygon,.node path){fill:var(--block-bg,var(--tint));stroke:var(--block-accent,var(--accent));stroke-width:1.5px}.sr-mermaid svg :is(.flowchart-link,.edge-thickness-normal){stroke:var(--block-accent,var(--accent));stroke-width:2px;fill:none}.sr-mermaid svg marker path{fill:var(--block-accent,var(--accent));stroke:var(--block-accent,var(--accent))}.sr-mermaid svg .cluster rect{fill:var(--wash);stroke:var(--rule)}.sr-mermaid svg .edgeLabel rect{fill:var(--surface);opacity:.95}.sr-mermaid svg .edge-pattern-dashed{stroke-dasharray:5,5}.sr-mermaid svg .edge-pattern-dotted{stroke-dasharray:2,3}.sr-diagram-error{color:var(--ink);background:var(--wash);border:2px solid var(--accent);border-radius:8px;padding:20px;font-size:calc(18px * var(--slide-font-scale,1) * var(--block-font-scale,1));white-space:pre-wrap;overflow-wrap:anywhere}.layout-title .sr-mermaid{--ink:#fff;--tint:#ffffff16;--accent:#a4e5f0;--surface:var(--cover)}
    .layout-statement .sr-content{align-content:center}.layout-statement .block-text{justify-content:center;font-size:calc(38px * var(--slide-font-scale,1) * var(--block-font-scale,1));line-height:1.35;letter-spacing:-.5px}.layout-statement .block-text .sr-heading{font-size:calc(42px * var(--slide-font-scale,1) * var(--block-font-scale,1))}.layout-cards .sr-content{gap:20px}.layout-cards .sr-block{border:1.5px solid var(--rule);border-radius:11px;padding:22px 25px;font-size:calc(22px * var(--slide-font-scale,1) * var(--block-font-scale,1));background:var(--surface)}.layout-cards .block-callout{border-left:5px solid var(--accent)}.layout-cards .sr-heading{font-size:calc(24px * var(--slide-font-scale,1) * var(--block-font-scale,1));color:var(--deep)}
    .density-compact .sr-header{margin-bottom:20px}.density-compact .sr-content{gap:18px 26px}.density-compact .sr-block{gap:9px}.density-compact{--body-font-size:22px;font-size:calc(22px * var(--slide-font-scale,1) * var(--block-font-scale,1))}.density-compact .block-callout,.density-compact.layout-cards .sr-block{font-size:calc(21px * var(--slide-font-scale,1) * var(--block-font-scale,1));padding:18px 21px}.density-compact .sr-copy p+p{margin-top:11px}.density-compact .sr-copy li{margin-bottom:9px}.density-compact table{font-size:calc(19px * var(--slide-font-scale,1) * var(--block-font-scale,1))}.density-compact th,.density-compact td{padding-top:8px;padding-bottom:8px}
    .sr-background-layer,.sr-background-overlay{position:absolute;inset:0;pointer-events:none}.sr-background-layer{z-index:0;background:var(--surface)}.sr-slide .sr-background-image{width:100%;height:100%;position:absolute;inset:0;border-radius:0}.sr-slide .sr-header,.sr-slide .sr-content{position:relative;z-index:1}.sr-slide .sr-footer{z-index:1}
    .has-background{color:var(--slide-text)}.has-background .sr-header .sr-kicker,.has-background .sr-header .sr-subtitle,.has-background .sr-footer{color:var(--slide-text)}.has-background .block-text>.sr-caption,.has-background .block-figure>.sr-caption{color:var(--slide-text)}
    .block-callout,.block-metric{color:var(--ink)}.has-background .block-callout,.has-background .block-metric,.has-background.layout-cards .sr-block,.has-background .block-table{color:var(--ink)}.has-background.layout-title .block-callout{background:var(--wash);color:var(--ink);border-left-color:var(--accent)}.has-background.layout-title .block-callout .sr-heading{color:var(--deep)}.has-background.layout-title .block-callout .sr-caption{color:var(--muted)}.has-background .block-table{background:var(--surface);padding:18px 22px;border-radius:9px}
    .sr-slide .sr-block.custom-bg{background:var(--block-bg)}.sr-slide .sr-block.custom-bg:is(.block-text,.block-figure,.block-table){padding:20px 24px;border-radius:9px}.sr-slide .sr-block.custom-bg tbody tr:nth-child(even){background:transparent}
    .sr-slide .sr-block.custom-accent{border-color:var(--block-accent)}.sr-slide .sr-block.custom-accent .sr-heading{color:var(--block-accent)}.sr-slide .sr-block.custom-accent th{border-bottom-color:var(--block-accent)}
    .sr-slide .sr-block.custom-fg,.sr-slide .sr-block.custom-fg :is(.sr-heading,.sr-copy,.sr-caption),.sr-slide .sr-block.custom-fg th,.sr-slide .sr-block.custom-fg td{color:var(--block-fg)}.sr-slide .sr-block.custom-fg td{border-bottom-color:var(--block-fg)}
    .sr-slide .sr-block.custom-header-bg th{background:var(--block-header-bg)}.sr-slide .sr-block.custom-header-fg th{color:var(--block-header-fg)}
    .sr-copy :is(h1,h2,h3,h4,h5,h6){margin:0 0 .45em;font-weight:700;line-height:1.2}.sr-copy h1{font-size:1.7em}.sr-copy h2{font-size:1.4em}.sr-copy h3{font-size:1.2em}.sr-copy :is(h4,h5,h6){font-size:1em}.sr-copy blockquote{margin:.5em 0;padding:.25em .8em;border-left:3px solid var(--accent)}.sr-copy pre{font-size:.9em;white-space:pre-wrap;overflow-wrap:anywhere}.sr-copy code{font-family:ui-monospace,Menlo,monospace}.sr-copy ol{padding-left:1.1em}.sr-copy hr{width:100%;border:0;border-top:1px solid var(--rule)}
    .sr-copy pre,.sr-copy pre.sr-code{display:block;margin:.5em 0;padding:.75em 1em;border:1px solid var(--rule);border-radius:8px;background:var(--tint);color:var(--ink);font-family:ui-monospace,"SFMono-Regular",Menlo,Consolas,monospace;font-size:calc(22px * var(--slide-font-scale,1) * var(--block-font-scale,1));line-height:1.35;white-space:pre-wrap;overflow-wrap:anywhere;tab-size:4;letter-spacing:0;text-align:left;max-width:100%;box-shadow:none}.sr-copy pre code{display:block;padding:0;margin:0;border:0;background:transparent;color:inherit;font-family:inherit;font-size:inherit;line-height:inherit;white-space:inherit;overflow:visible;max-height:none}.sr-copy :not(pre)>code{font-size:.88em;padding:.08em .24em;background:var(--tint);border-radius:3px}.sr-token-keyword{color:var(--accent);font-weight:650}.sr-token-string{color:var(--deep)}.sr-token-number,.sr-token-type{color:var(--accent)}.sr-token-comment{color:var(--muted);font-style:italic}.sr-token-function{color:var(--secondary);font-weight:600}.layout-title .sr-copy pre{--ink:#fff;--tint:#ffffff16;--rule:#ffffff55;--accent:#a4e5f0;--deep:#b7efd3;--muted:#ffffffb3;--secondary:#efdaaa}
    .sr-preview [data-block-id]{cursor:pointer}.sr-preview [data-block-id]:hover{outline:2px solid #2a78d670;outline-offset:-2px}
    .reveal{font-family:inherit;font-size:calc(25px * var(--slide-font-scale,1) * var(--block-font-scale,1))}.reveal .slides{text-align:left}.reveal .slides>section{padding:0;width:1280px;height:720px}.reveal .slides .sr-slide{display:flex}.reveal .controls{color:var(--accent)}.reveal .progress{color:var(--accent);height:3px}.reveal aside.notes{display:none}
    #presenter-notes{display:none;position:fixed;z-index:100;left:3%;right:3%;bottom:3%;max-height:35%;overflow:auto;background:#151a22f5;color:#fff;border-radius:12px;padding:24px 30px;font-size:calc(21px * var(--slide-font-scale,1) * var(--block-font-scale,1));line-height:1.5;box-shadow:0 4px 30px #0005;white-space:normal}#presenter-notes.visible{display:block}#presenter-notes p{margin:0 0 10px}
    @media print{html,body{background:#fff}#presenter-notes{display:none!important}.sr-slide{-webkit-print-color-adjust:exact;print-color-adjust:exact}}
    """
}

/// Prefer the relocatable application bundle over SwiftPM's development paths.
enum CoreResources {
    static func url(_ name: String, extension ext: String) -> URL? {
        if let root = Bundle.main.resourceURL {
            let packaged = root.appendingPathComponent("SwiftReveal_SwiftRevealCore.bundle")
            if let bundle = Bundle(url: packaged), let resource = bundle.url(forResource: name, withExtension: ext.isEmpty ? nil : ext, subdirectory: "Resources") { return resource }
            let base = root.appendingPathComponent("Resources").appendingPathComponent(name)
            let direct = ext.isEmpty ? base : base.appendingPathExtension(ext)
            if FileManager.default.fileExists(atPath: direct.path) { return direct }
        }
        return Bundle.module.url(forResource: name, withExtension: ext.isEmpty ? nil : ext, subdirectory: "Resources")
    }
}
