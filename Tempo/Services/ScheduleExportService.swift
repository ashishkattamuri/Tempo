import SwiftUI

@MainActor
final class ScheduleExportService {
    static let shared = ScheduleExportService()
    private init() {}


    func renderImage(date: Date, items: [ScheduleItem]) -> UIImage? {
        let view = ScheduleExportView(date: date, items: items)
            .frame(width: 390) 
            .environment(\.colorScheme, .light) 

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0 
        return renderer.uiImage
    }

   
    func exportAndShare(date: Date, items: [ScheduleItem], presenting sourceView: UIView? = nil) {
        guard let image = renderImage(date: date, items: items) else { return }

        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )

     
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = sourceView ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController?
            .present(activityVC, animated: true)
    }
}