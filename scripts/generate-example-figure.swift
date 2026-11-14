import AppKit
let width=1400, height=720
let image=NSImage(size:NSSize(width:width,height:height))
image.lockFocus()
NSColor.white.setFill(); NSRect(x:0,y:0,width:width,height:height).fill()
func label(_ text:String,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat,_ color:NSColor = .darkGray,_ weight:NSFont.Weight = .regular){
 (text as NSString).draw(at:NSPoint(x:x,y:y),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:weight),.foregroundColor:color])
}
let blue=NSColor(calibratedRed:0.165,green:0.47,blue:0.84,alpha:1)
let ink=NSColor(calibratedWhite:0.12,alpha:1)
label("Illustrative category values",48,654,32,ink,.semibold)
label("A generic example chart imported as an image",48,612,22,.gray)
let plotX:CGFloat=430, plotW:CGFloat=840, base:CGFloat=120, top:CGFloat=565
for tick in 0...4 {
 let x=plotX+CGFloat(tick)*plotW/4
 NSColor(calibratedWhite:0.91,alpha:1).setStroke()
 let line=NSBezierPath();line.move(to:NSPoint(x:x,y:base));line.line(to:NSPoint(x:x,y:top));line.lineWidth=1;line.stroke()
 label(String(format:"%.1f",Double(tick)*0.5),x-17,78,22,.gray)
}
let studies=[("Category A",0.72,0.42,1.02), ("Category B",1.20,0.95,1.45), ("Category C",0.96,0.65,1.27), ("Category D",0.98,0.80,1.16)]
for (i,s) in studies.enumerated(){
 let y:CGFloat=510-CGFloat(i)*100
 label(s.0,48,y-14,26,ink,i==3 ? .semibold : .regular)
 let cx=plotX+CGFloat(s.1/2)*plotW, lo=plotX+CGFloat(s.2/2)*plotW, hi=plotX+CGFloat(s.3/2)*plotW
 blue.setStroke();let ci=NSBezierPath();ci.move(to:NSPoint(x:lo,y:y));ci.line(to:NSPoint(x:hi,y:y));ci.lineWidth=5;ci.stroke()
 blue.setFill();NSBezierPath(roundedRect:NSRect(x:cx-10,y:y-10,width:20,height:20),xRadius:4,yRadius:4).fill()
}
label("Value (arbitrary units)",610,20,24,ink)
image.unlockFocus()
let bitmap=NSBitmapImageRep(data:image.tiffRepresentation!)!
let png=bitmap.representation(using:.png,properties:[:])!
try png.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
