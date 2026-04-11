// GestureOverlayView.swift
// Transparent UIViewRepresentable overlay that owns UIKit gesture recognizers
// for painting (pan) and zoom (pinch), with clean delegate-based deconfliction.
// The pan delegate checks pinch.state before allowing pan to begin — no
// require(toFail:) delay, zero lag on paint start.

#if os(iOS)
import SwiftUI
import UIKit

struct GestureOverlayView: UIViewRepresentable {

    var onDragChanged:  (CGPoint) -> Void
    var onDragEnded:    () -> Void
    var onPinchChanged: (CGFloat) -> Void   // cumulative scale from gesture start
    var onPinchEnded:   () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let pan   = UIPanGestureRecognizer(target:   context.coordinator,
                                           action:   #selector(Coordinator.handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: context.coordinator,
                                             action: #selector(Coordinator.handlePinch(_:)))
        let tap   = UITapGestureRecognizer(target:   context.coordinator,
                                           action:   #selector(Coordinator.handleTap(_:)))

        pan.maximumNumberOfTouches = 1
        pan.delegate   = context.coordinator
        pinch.delegate = context.coordinator
        tap.delegate   = context.coordinator

        context.coordinator.pan   = pan
        context.coordinator.pinch = pinch

        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: GestureOverlayView
        weak var pan:   UIPanGestureRecognizer?
        weak var pinch: UIPinchGestureRecognizer?

        init(_ parent: GestureOverlayView) { self.parent = parent }

        // Pan only begins when no pinch is in progress
        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            guard g === pan else { return true }
            return pinch?.state == .possible || pinch?.state == nil
        }

        // Never allow simultaneous recognition between pan and pinch
        func gestureRecognizer(
            _ g: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { false }

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            let point = g.location(in: g.view)
            parent.onDragChanged(point)
            parent.onDragEnded()
        }

        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            let point = g.location(in: g.view)
            switch g.state {
            case .began, .changed:
                parent.onDragChanged(point)
            case .ended, .cancelled, .failed:
                parent.onDragEnded()
            default:
                break
            }
        }

        @objc func handlePinch(_ g: UIPinchGestureRecognizer) {
            switch g.state {
            case .began, .changed:
                parent.onPinchChanged(g.scale)
            case .ended, .cancelled, .failed:
                parent.onPinchEnded()
            default:
                break
            }
        }
    }
}
#endif
