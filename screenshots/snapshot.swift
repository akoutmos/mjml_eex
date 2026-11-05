// Takes screenshots of HTML files with WebKit, the engine of Apple Mail and Safari. Used by
// `mix mjml_eex.gen.screenshots`, which writes the jobs file.
//
// Usage: swift snapshot.swift <jobs.json>
//
// The jobs file:
//
//     {
//       "root": "/path/to/project",
//       "jobs": [
//         {
//           "input": "/path/to/email.html",
//           "width": 680,
//           "height": null,
//           "transparent": false,
//           "outputs": [
//             {"path": "/path/to/email.png", "width": 1360},
//             {"path": "/path/to/email.jpg", "width": 1020, "quality": 0.85}
//           ]
//         }
//       ]
//     }
//
// `width` and `height` are the size of the window in CSS pixels. Without a height, the
// screenshot is of the whole page. Each output is scaled to its width in pixels, keeping the
// aspect ratio, and is a JPEG when its path ends in .jpg, or a PNG. WebKit can read the files
// under `root`, such as the images an HTML file uses.

import AppKit
import WebKit

struct Output: Decodable {
  let path: String
  let width: Int
  let quality: Double?
}

struct Job: Decodable {
  let input: String
  let width: Double
  let height: Double?
  let transparent: Bool?
  let outputs: [Output]
}

struct Jobs: Decodable {
  let root: String
  let jobs: [Job]
}

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data((message + "\n").utf8))
  exit(1)
}

guard CommandLine.arguments.count == 2 else { fail("usage: swift snapshot.swift <jobs.json>") }

let spec: Jobs

do {
  let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
  spec = try JSONDecoder().decode(Jobs.self, from: data)
} catch {
  fail("can't read \(CommandLine.arguments[1]): \(error)")
}

final class Runner: NSObject, WKNavigationDelegate {
  let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
  var index = 0
  var deadline = DispatchWorkItem {}

  override init() {
    super.init()
    webView.navigationDelegate = self
  }

  var job: Job { spec.jobs[index] }

  func next() {
    guard index < spec.jobs.count else { exit(0) }

    // A page that takes this long is stuck
    deadline.cancel()
    deadline = DispatchWorkItem { [job] in fail("timed out taking a screenshot of \(job.input)") }
    DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: deadline)

    webView.setValue(!(job.transparent ?? false), forKey: "drawsBackground")
    webView.frame = NSRect(x: 0, y: 0, width: job.width, height: job.height ?? 100)
    webView.loadFileURL(URL(fileURLWithPath: job.input), allowingReadAccessTo: URL(fileURLWithPath: spec.root))
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    waitForImages(attempts: 100)
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    fail("can't load \(job.input): \(error)")
  }

  func webView(
    _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error
  ) {
    fail("can't load \(job.input): \(error)")
  }

  func waitForImages(attempts: Int) {
    webView.evaluateJavaScript("Array.from(document.images).every(image => image.complete)") { result, _ in
      if (result as? Bool) == true || attempts == 0 {
        self.resize()
      } else {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.waitForImages(attempts: attempts - 1) }
      }
    }
  }

  // Makes the window as tall as the page, unless the job has a height
  func resize() {
    if let height = job.height {
      settle(height: height)
      return
    }

    webView.evaluateJavaScript("document.documentElement.scrollHeight") { result, _ in
      let height = (result as? Double) ?? 100
      self.webView.frame = NSRect(x: 0, y: 0, width: self.job.width, height: height)
      self.settle(height: height)
    }
  }

  // Gives WebKit time to lay out and paint the page at its size
  func settle(height: Double) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.snapshot(height: height) }
  }

  func snapshot(height: Double) {
    let config = WKSnapshotConfiguration()
    config.rect = NSRect(x: 0, y: 0, width: job.width, height: height)

    webView.takeSnapshot(with: config) { image, error in
      guard let image = image, let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fail("can't take a screenshot of \(self.job.input): \(String(describing: error))")
      }

      for output in self.job.outputs {
        write(cgImage, to: output)
        print("  " + output.path.replacingOccurrences(of: spec.root + "/", with: ""))
      }

      self.index += 1
      self.next()
    }
  }
}

func write(_ image: CGImage, to output: Output) {
  let width = output.width
  let height = Int((Double(image.height) * Double(width) / Double(image.width)).rounded())

  guard
    let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
  else { fail("can't scale the screenshot for \(output.path)") }

  context.interpolationQuality = .high
  context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

  let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)

  let data =
    output.path.hasSuffix(".jpg")
    ? bitmap.representation(using: .jpeg, properties: [.compressionFactor: output.quality ?? 0.85])
    : bitmap.representation(using: .png, properties: [:])

  do {
    let url = URL(fileURLWithPath: output.path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data!.write(to: url)
  } catch {
    fail("can't write \(output.path): \(error)")
  }
}

let app = NSApplication.shared
let runner = Runner()
DispatchQueue.main.async { runner.next() }
app.run()
