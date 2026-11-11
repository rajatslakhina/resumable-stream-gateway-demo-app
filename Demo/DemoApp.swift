import Foundation
import StreamGateway
import StreamGatewayUI
import SwiftUI

@main
struct StreamGatewayDemoApp: App {
    var body: some Scene {
        WindowGroup {
            StreamLabView(configuration: DemoConfiguration.make())
        }
    }
}

/// The app owns the lab's configuration: the scripted "model output" and the
/// gateway limits each scenario starts from (from the core `StreamGateway`
/// module). The lab view only takes it as a parameter.
enum DemoConfiguration {
    /// Stands in for a Claude response. 142 tokens at 45 ms each is about
    /// 6.4 seconds of streaming, long enough for every fault to land mid-stream.
    static let script = """
    A token stream is not a request, it is a session. Phones change networks, \
    the OS suspends apps, and proxies close idle sockets, so a client that restarts \
    the prompt on every drop pays for the same answer twice and still shows the \
    user a stutter. The gateway makes one upstream call per stream, appends every \
    delta to a bounded replay log, and gives each frame a cursor. The client sends \
    that cursor back as Last-Event-ID, drops anything it already has, and refuses \
    to build a transcript with a hole in it. When the log no longer covers the gap, \
    the gateway says so with a 410 instead of guessing, and the app restarts cleanly. \
    Backpressure is a cut, not a buffer: a stalled connection is closed and resumes \
    from the shared log, so one slow phone never grows the server's memory.
    """

    static func make(arguments: [String] = ProcessInfo.processInfo.arguments) -> LabConfiguration {
        var scenario = LabScenario.dropMidStream
        if let flag = arguments.firstIndex(of: "-scenario"),
           arguments.indices.contains(flag + 1),
           let parsed = LabScenario(rawValue: arguments[flag + 1]) {
            scenario = parsed
        }
        let gateway = GatewayConfiguration(replayFrameCapacity: 2048,
                                           replayByteCapacity: 512 * 1024,
                                           maxFramePayloadBytes: 4096,
                                           subscriberQueueLimit: 64,
                                           retention: .seconds(60),
                                           abandonTimeout: .seconds(30),
                                           maxStreams: 16)
        return LabConfiguration(script: script,
                                tokenInterval: .milliseconds(45),
                                baseGateway: gateway,
                                initialScenario: scenario,
                                autoStart: true)
    }
}
