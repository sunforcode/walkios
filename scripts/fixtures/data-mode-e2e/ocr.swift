import Vision
import AppKit
let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard let img = NSImage(contentsOf: url), let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { exit(2) }
let req = VNRecognizeTextRequest()
req.recognitionLanguages = ["zh-Hans", "en-US"]
req.recognitionLevel = .accurate
try VNImageRequestHandler(cgImage: cg).perform([req])
for obs in req.results ?? [] { if let t = obs.topCandidates(1).first?.string { print(t) } }
