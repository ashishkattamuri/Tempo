//
//  TempoLiveActivityLiveActivity.swift
//  TempoLiveActivity
//
//  Created by Shlok Mestry on 01/03/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TempoLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TempoLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TempoLiveActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension TempoLiveActivityAttributes {
    fileprivate static var preview: TempoLiveActivityAttributes {
        TempoLiveActivityAttributes(name: "World")
    }
}

extension TempoLiveActivityAttributes.ContentState {
    fileprivate static var smiley: TempoLiveActivityAttributes.ContentState {
        TempoLiveActivityAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TempoLiveActivityAttributes.ContentState {
         TempoLiveActivityAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TempoLiveActivityAttributes.preview) {
   TempoLiveActivityLiveActivity()
} contentStates: {
    TempoLiveActivityAttributes.ContentState.smiley
    TempoLiveActivityAttributes.ContentState.starEyes
}
