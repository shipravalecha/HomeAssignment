// BarcodeScannerView.swift
// ChefNova
//
// A SwiftUI wrapper around AVFoundation's barcode scanning pipeline.
// Supports UPC-A, UPC-E, EAN-8, EAN-13, Code-128, QR, and DataMatrix —
// covering virtually all grocery product barcodes.
//
// Usage:
//   BarcodeScannerView { barcode in
//       // handle scanned barcode string
//   }

import SwiftUI
@preconcurrency import AVFoundation

// MARK: - Public SwiftUI view

/// Presents a live camera viewfinder that scans barcodes and calls `onScan`
/// with the decoded string value. Dismisses automatically after the first
/// successful scan.
struct BarcodeScannerView: View {

    /// Called on the main thread with the decoded barcode string.
    let onScan: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cameraPermission: CameraPermission = .unknown
    @State private var torchOn = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch cameraPermission {
            case .unknown:
                ProgressView()
                    .tint(.white)
                    .onAppear { requestCameraPermission() }

            case .denied:
                cameraPermissionDeniedView

            case .granted:
                scannerContent
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(.white)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    torchOn.toggle()
                } label: {
                    Image(systemName: torchOn ? "bolt.fill" : "bolt.slash.fill")
                }
                .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Scanner content

    private var scannerContent: some View {
        ZStack {
            // Live camera feed
            CameraPreviewRepresentable(torchOn: $torchOn) { barcode in
                dismiss()
                onScan(barcode)
            }
            .ignoresSafeArea()

            // Viewfinder overlay
            viewfinderOverlay
        }
    }

    // MARK: - Viewfinder overlay

    private var viewfinderOverlay: some View {
        GeometryReader { geo in
            let boxW = geo.size.width * 0.75
            let boxH = boxW * 0.55
            let boxX = (geo.size.width - boxW) / 2
            let boxY = (geo.size.height - boxH) / 2

            ZStack {
                // Dimmed surround
                Rectangle()
                    .fill(Color.black.opacity(0.55))
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .frame(width: boxW, height: boxH)
                                    .blendMode(.destinationOut)
                            )
                    )

                // Corner brackets
                CornerBrackets(rect: CGRect(x: boxX, y: boxY, width: boxW, height: boxH))
                    .stroke(Color.orange, lineWidth: 3)

                // Instruction label
                VStack {
                    Spacer()
                        .frame(height: boxY + boxH + 24)
                    Text("Point at a product barcode")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Permission denied view

    private var cameraPermissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Camera Access Required")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Please enable camera access in Settings to scan barcodes.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
    }

    // MARK: - Permission request

    private func requestCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermission = .granted
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermission = granted ? .granted : .denied
                }
            }
        default:
            cameraPermission = .denied
        }
    }

    // MARK: - Permission state

    private enum CameraPermission {
        case unknown, granted, denied
    }
}

// MARK: - Corner brackets shape

private struct CornerBrackets: Shape {
    let rect: CGRect
    let armLength: CGFloat = 22

    func path(in _: CGRect) -> Path {
        var p = Path()
        let r = rect
        let a = armLength

        // Top-left
        p.move(to: CGPoint(x: r.minX, y: r.minY + a))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + a, y: r.minY))

        // Top-right
        p.move(to: CGPoint(x: r.maxX - a, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + a))

        // Bottom-right
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - a))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - a, y: r.maxY))

        // Bottom-left
        p.move(to: CGPoint(x: r.minX + a, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - a))

        return p
    }
}

// MARK: - UIKit camera preview (AVFoundation)

/// `UIViewControllerRepresentable` that hosts the AVFoundation capture session.
private struct CameraPreviewRepresentable: UIViewControllerRepresentable {

    @Binding var torchOn: Bool
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        CameraViewController(onScan: onScan)
    }

    func updateUIViewController(_ vc: CameraViewController, context: Context) {
        vc.setTorch(on: torchOn)
    }
}

// MARK: - CameraViewController

private final class CameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    private let onScan: (String) -> Void
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    init(onScan: @escaping (String) -> Void) {
        self.onScan = onScan
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            let captureSession = session
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    // MARK: - Session setup

    private func setupSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [
            .ean8, .ean13, .upce,
            .code128, .code39, .code93,
            .qr, .dataMatrix, .pdf417
        ]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview

        let captureSession = session
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
    }

    // MARK: - Torch

    func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue,
              !value.isEmpty else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self, !self.hasScanned else { return }
            self.hasScanned = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            self.onScan(value)
        }
    }
}
