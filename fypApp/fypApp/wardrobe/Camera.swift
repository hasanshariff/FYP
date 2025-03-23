//
//  Camera.swift
//  fypApp
//
//  Created by Hasan Shariff on 11/02/2025.
//

import UIKit
import AVFoundation
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

class ImageClassifierViewController: UIViewController, AVCapturePhotoCaptureDelegate, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    // MARK: - UI Elements
    private let previewView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let captureButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .white
        button.layer.cornerRadius = 30
        button.layer.borderWidth = 5
        button.layer.borderColor = UIColor.systemBlue.cgColor
        return button
    }()
    
    private let retakeButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Retake", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemRed
        button.layer.cornerRadius = 10
        button.isHidden = true
        return button
    }()
    
    private let imageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .clear // Make sure background is clear
        view.isHidden = true
        return view
    }()
    
    private let resultLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = .white
        label.backgroundColor = .black.withAlphaComponent(0.7)
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.isHidden = true
        return label
    }()
    
    private let closeModuleButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("×", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 40, weight: .bold)
        button.setTitleColor(.systemRed, for: .normal)
        button.backgroundColor = .black.withAlphaComponent(0.6)
        button.layer.cornerRadius = 22
        return button
    }()
    
    // MARK: - Properties
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?
    private var currentImage: UIImage?
    
    private let db = Firestore.firestore()
    private var rgbValues: (red: Double, green: Double, blue: Double) = (0, 0, 0)
    
    private var interfaceStyleObserver: NSKeyValueObservation?

    // Modal Views
    private let modalView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 20
        view.isHidden = true
        view.isUserInteractionEnabled = true
        return view
    }()

    private let modalBackground: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .black.withAlphaComponent(0.7)
        view.isHidden = true
        return view
    }()

    
    private let confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Confirm", for: .normal)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.isHidden = true
        return button
    }()

    private let sizePicker: UIPickerView = {
        let picker = UIPickerView()
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.isHidden = true
        return picker
    }()
    
    private let sizeDropdownButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Select Size ▼", for: .normal)
        button.contentHorizontalAlignment = .left
        button.layer.borderWidth = 1
        button.layer.cornerRadius = 8
        button.backgroundColor = .systemBackground
        return button
    }()

    private let sizeTableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.isHidden = true
        tableView.layer.cornerRadius = 8
        tableView.layer.borderWidth = 1
        tableView.backgroundColor = .systemBackground
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SizeCell")
        tableView.layer.zPosition = 999 // Ensure it's above other views
        tableView.clipsToBounds = true
        return tableView
    }()
        
    private let sizeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Size:"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .black
        label.isUserInteractionEnabled = true
        return label
    }()
        
    private let clothingSizes = ["XXS", "XS", "S", "M", "L", "XL", "XXL"]
    private let shoeSizes = Array(3...15).map { "UK \($0)" }
    private var currentSizes: [String] = []

    private let brandTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: textField.frame.height))
        textField.leftView = paddingView
        textField.leftViewMode = .always
        textField.placeholder = "Enter brand name"
        textField.borderStyle = .roundedRect
        textField.backgroundColor = .systemBackground
        textField.returnKeyType = .done
        return textField
    }()

    private let typeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 24, weight: .semibold)
        label.textColor = .label // Adapts to dark/light mode
        label.numberOfLines = 0 // Allow multiple lines
        label.textAlignment = .center
        return label
    }()
    
    private let rgbLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.textAlignment = .left
            label.text = "RGB Values:"
            return label
        }()
    
    private let hsvLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.textAlignment = .left
            label.text = "HSV Values:"
            return label
        }()

    private let saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Save", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemPurple
        button.layer.cornerRadius = 10
        return button
    }()

    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("×", for: .normal)
        button.setTitleColor(.systemRed, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 24, weight: .bold)
        return button
    }()
    
    // Drawing properties
    private var startPoint: CGPoint?
    private var boundingBoxView: UIView?
    private var currentBoundingBox: CGRect?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCamera()
        
        // Add this line
        sizeTableView.register(UITableViewCell.self, forCellReuseIdentifier: "SizeCell")
        
        // Store the observer in the property
        interfaceStyleObserver = self.observe(\.traitCollection.userInterfaceStyle) { [weak self] _, _ in
            self?.updateInterfaceColors()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }
    
    // MARK: - UIPickerViewDelegate & UIPickerViewDataSource Methods
        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            return 1
        }
        
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            return currentSizes.count
        }
        
        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
            return currentSizes[row]
        }
   
    // MARK: - UITableViewDataSource Methods
    // Table view delegate methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentSizes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SizeCell", for: indexPath)
        cell.textLabel?.text = currentSizes[indexPath.row]
        cell.backgroundColor = traitCollection.userInterfaceStyle == .dark ? .darkGray : .white
        cell.textLabel?.textColor = traitCollection.userInterfaceStyle == .dark ? .white : .black
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedSize = currentSizes[indexPath.row]
        sizeDropdownButton.setTitle("\(selectedSize) ▼", for: .normal)
        toggleSizeDropdown()
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = .black
        
        // Add subviews
        view.addSubview(previewView)
        view.addSubview(captureButton)
        view.addSubview(imageView)
        view.addSubview(retakeButton)
        view.addSubview(resultLabel)
        view.addSubview(confirmButton)
        view.addSubview(closeModuleButton)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            captureButton.widthAnchor.constraint(equalToConstant: 60),
            captureButton.heightAnchor.constraint(equalToConstant: 60),
            
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            retakeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            retakeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            retakeButton.widthAnchor.constraint(equalToConstant: 100),
            retakeButton.heightAnchor.constraint(equalToConstant: 44),
            
            resultLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            resultLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            resultLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40),
            resultLabel.heightAnchor.constraint(equalToConstant: 44),
            
            confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            confirmButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            confirmButton.widthAnchor.constraint(equalToConstant: 100),
            confirmButton.heightAnchor.constraint(equalToConstant: 44),
            
            closeModuleButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            closeModuleButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            closeModuleButton.widthAnchor.constraint(equalToConstant: 44),
            closeModuleButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Add targets
        captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        retakeButton.addTarget(self, action: #selector(retakeButtonTapped), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
        closeModuleButton.addTarget(self, action: #selector(closeModuleTapped), for: .touchUpInside)
        
        // Setup gesture recognizers
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        imageView.addGestureRecognizer(panGesture)
        imageView.isUserInteractionEnabled = true
        
        NotificationCenter.default.addObserver(self,
                selector: #selector(keyboardWillShow),
                name: UIResponder.keyboardWillShowNotification,
                object: nil)
            NotificationCenter.default.addObserver(self,
                selector: #selector(keyboardWillHide),
                name: UIResponder.keyboardWillHideNotification,
                object: nil)
                    
            // Set text field delegate
            brandTextField.delegate = self
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if self.view.frame.origin.y == 0 {
                self.view.frame.origin.y -= keyboardSize.height/3
            }
        }
    }
        
    @objc private func keyboardWillHide(notification: NSNotification) {
        if self.view.frame.origin.y != 0 {
            self.view.frame.origin.y = 0
        }
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession,
              let backCamera = AVCaptureDevice.default(for: .video) else { return }
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            photoOutput = AVCapturePhotoOutput()
            
            if captureSession.canAddInput(input) && captureSession.canAddOutput(photoOutput!) {
                captureSession.addInput(input)
                captureSession.addOutput(photoOutput!)
                setupPreviewLayer()
            }
        } catch {
            showAlert(message: "Error setting up camera: \(error.localizedDescription)")
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            captureSession.startRunning()
        }
    }
    
    private func setupPreviewLayer() {
        guard let captureSession = captureSession else { return }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        previewView.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
    }
    
    // MARK: - Action Methods
    @objc private func captureButtonTapped() {
        guard let photoOutput = photoOutput else { return }
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    @objc private func confirmButtonTapped() {
        showModal()
    }

    @objc private func sizeLabelTapped() {
        sizePicker.isHidden = !sizePicker.isHidden
    }

    
    @objc private func retakeButtonTapped() {
        // Reset UI for new photo
        imageView.isHidden = true
        previewView.isHidden = false
        captureButton.isHidden = false
        retakeButton.isHidden = true
        resultLabel.isHidden = true
        boundingBoxView?.removeFromSuperview()
        boundingBoxView = nil
        currentBoundingBox = nil
        currentImage = nil
        confirmButton.isHidden = true
    }
    
    @objc private func closeModuleTapped() {
        // Stop capture session
        captureSession?.stopRunning()
        
        // Dismiss the view controller
        dismiss(animated: true)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard currentImage != nil else { return }
        
        switch gesture.state {
        case .began:
            startPoint = gesture.location(in: imageView)
            boundingBoxView?.removeFromSuperview()
            resultLabel.isHidden = true
            
        case .changed:
            guard let startPoint = startPoint else { return }
            let currentPoint = gesture.location(in: imageView)
            
            // Calculate bounding box
            let rect = CGRect(
                x: min(startPoint.x, currentPoint.x),
                y: min(startPoint.y, currentPoint.y),
                width: abs(currentPoint.x - startPoint.x),
                height: abs(currentPoint.y - startPoint.y)
            )
            
            // Update or create bounding box view
            if boundingBoxView == nil {
                boundingBoxView = UIView()
                boundingBoxView?.layer.borderWidth = 2
                boundingBoxView?.layer.borderColor = UIColor.green.cgColor
                boundingBoxView?.backgroundColor = .clear
                imageView.addSubview(boundingBoxView!)
            }
            
            boundingBoxView?.frame = rect
            currentBoundingBox = rect
            
        case .ended:
            guard let boundingBox = currentBoundingBox else { return }
            
            // Show confirmation alert
            let alert = UIAlertController(
                title: "Confirm Selection",
                message: "Are you happy with the selected area?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Yes", style: .default) { [weak self] _ in
                self?.processSelectedArea(boundingBox)
            })
            
            alert.addAction(UIAlertAction(title: "No", style: .cancel) { [weak self] _ in
                self?.boundingBoxView?.removeFromSuperview()
                self?.boundingBoxView = nil
                self?.currentBoundingBox = nil
            })
            
            present(alert, animated: true)
            
        default:
            break
        }
    }

    // NEW FUNCTION
    private func processSelectedArea(_ boundingBox: CGRect) {
        guard let image = currentImage else { return }
        
        // Calculate scaled box (keeping your existing scaling code)
        let imageSize = image.size
        let viewSize = imageView.bounds.size
        
        let scaleX = imageSize.width / viewSize.width
        let scaleY = imageSize.height / viewSize.height
        
        let imageBox = CGRect(
            x: boundingBox.minX * scaleX,
            y: boundingBox.minY * scaleY,
            width: boundingBox.width * scaleX,
            height: boundingBox.height * scaleY
        )
        
        // Crop image to bounding box
        guard let cgImage = image.cgImage?.cropping(to: imageBox) else {
            print("Failed to crop image")
            return
        }

        let croppedImage = CIImage(cgImage: cgImage)

        // Remove background
        removeBackground(from: croppedImage) { [weak self] processedImage in
            guard let processedImage = processedImage else {
                DispatchQueue.main.async {
                    self?.showAlert(message: "Failed to process image")
                }
                return
            }
            
            // Continue with classification
            self?.classifyImage(processedImage)
            
            DispatchQueue.main.async {
                            self?.imageView.image = processedImage
                            self?.imageView.isHidden = false
                            self?.previewView.isHidden = true
                            self?.captureButton.isHidden = true
                            self?.retakeButton.isHidden = false
                            self?.confirmButton.isHidden = false // Show confirm button only when background is removed
                        }
        }
    }
    // NEW FUNCTION
    private func removeBackground(from croppedImage: CIImage, completion: @escaping (UIImage?) -> Void) {
        let processingQueue = DispatchQueue(label: "ProcessingQueue")
        
        processingQueue.async {
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(ciImage: croppedImage)
            
            do {
                try handler.perform([request])
                
                guard let result = request.results?.first,
                      let maskBuffer = try? result.generateScaledMaskForImage(
                        forInstances: result.allInstances,
                        from: handler
                      ) else {
                    completion(nil)
                    return
                }
                
                let maskImage = CIImage(cvPixelBuffer: maskBuffer)
                
                let filter = CIFilter.blendWithMask()
                filter.inputImage = croppedImage
                filter.maskImage = maskImage
                filter.backgroundImage = CIImage.empty()
                
                guard let outputImage = filter.outputImage,
                      let cgImage = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
                    completion(nil)
                    return
                }
                
                let finalImage = UIImage(cgImage: cgImage)
                
                // Update the UI with the processed image
                DispatchQueue.main.async { [weak self] in
                    self?.imageView.image = finalImage
                    self?.currentImage = finalImage
                }
                
                self.analyzeColors(finalImage)
                
                completion(finalImage)
                
            } catch {
                print("Background removal error: \(error)")
                completion(nil)
            }
        }
    }
    
    // NEW FUNCTION
    private func classifyImage(_ image: UIImage) {
        // Create ML expects specific input sizes and processing
        let targetSize = CGSize(width: 416, height: 416)  // Standard YOLO input size
        
        UIGraphicsBeginImageContextWithOptions(targetSize, true, 1.0)
        let context = UIGraphicsGetCurrentContext()
        
        // Fill with white background first (for transparent images)
        context?.setFillColor(UIColor.white.cgColor)
        context?.fill(CGRect(origin: .zero, size: targetSize))
        
        // Draw the image (potentially with transparent background) on top
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let cgImage = resizedImage?.cgImage else {
            showAlert(message: "Error processing image")
            return
        }
        
        // Create ML specific pixel buffer creation
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault,
                           Int(targetSize.width),
                           Int(targetSize.height),
                           kCVPixelFormatType_32BGRA,
                           nil,
                           &pixelBuffer)
        
        guard let buffer = pixelBuffer else {
            showAlert(message: "Error creating pixel buffer")
            return
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        let pixelContext = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
        
        pixelContext?.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            
            let model = try newProject_1(configuration: config)
            let input = newProject_1Input(imagePath: buffer, iouThreshold: 0.45, confidenceThreshold: 0.25)
            let prediction = try model.prediction(input: input)
            
            // Debug print the raw predictions
            print("Confidence values: \(prediction.confidence)")
            print("Coordinates: \(prediction.coordinates)")
            
            handlePrediction(prediction)
        } catch {
            print("Classification error: \(error.localizedDescription)")
            showAlert(message: "Error classifying image: \(error.localizedDescription)")
        }
    }
    
    // NEW FUNCTION
    private func handlePrediction(_ prediction: newProject_1Output) {
        let confidences = prediction.confidence
        let coordinates = prediction.coordinates
        let classes = ["Shoes", "Tops", "Bottoms"]
        
        print("Processing prediction with shape: \(confidences.shape)")
        
        // Check if we have valid predictions
        guard confidences.shape[0].intValue > 0 else {
            DispatchQueue.main.async { [weak self] in
                self?.showAlert(message: "No valid predictions. Please try again.") { [weak self] in
                    self?.retakeButtonTapped()
                }
            }
            return
        }
        
        // Get confidence values directly
        let confidence0 = confidences[[0, 0] as [NSNumber]].doubleValue
        let confidence1 = confidences[[0, 1] as [NSNumber]].doubleValue
        let confidence2 = confidences[[0, 2] as [NSNumber]].doubleValue
        
        // Debug print raw values
        print("Raw confidences - 0: \(confidence0), 1: \(confidence1), 2: \(confidence2)")
        
        // Find highest confidence
        let confidenceArray = [confidence0, confidence1, confidence2]
        if let maxIndex = confidenceArray.indices.max(by: { confidenceArray[$0] < confidenceArray[$1] }) {
            let highestConfidence = confidenceArray[maxIndex]
            
            DispatchQueue.main.async { [weak self] in
                if highestConfidence > 0.25 {
                    let correctedIndex = (maxIndex + 2) % 3
                    let detectedClass = classes[correctedIndex]
                    
                    // Get coordinates directly
                    let x = coordinates[[0, 0] as [NSNumber]].doubleValue
                    let y = coordinates[[0, 1] as [NSNumber]].doubleValue
                    let w = coordinates[[0, 2] as [NSNumber]].doubleValue
                    let h = coordinates[[0, 3] as [NSNumber]].doubleValue
                    
                    let bbox = [x, y, w, h]
                    print("Detected \(detectedClass) with confidence \(highestConfidence) at coordinates: \(bbox)")
                    
                    self?.resultLabel.text = "\(detectedClass): \(Int(highestConfidence * 100))%"
                    self?.resultLabel.isHidden = false
                    
                    self?.confirmButton.isHidden = false
                    
                    // Update UI to show the processed image (with background removed)
                    if let processedImage = self?.currentImage {
                        self?.imageView.image = processedImage
                        self?.imageView.backgroundColor = .clear // Make sure background is clear
                        self?.boundingBoxView?.removeFromSuperview() // Remove the green bounding box
                    }
                    
                } else {
                    self?.showAlert(message: "No clothing item detected. Please try again.") { [weak self] in
                        self?.retakeButtonTapped()
                    }
                }
            }
        }
    }
    
    private func showModal() {
        // Make modal views visible
        modalBackground.isHidden = false
        modalView.isHidden = false
        
        // Update colors based on dark mode
        updateInterfaceColors()
        
        let detectedType = resultLabel.text?.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces) ?? ""
        let percentage = resultLabel.text?.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""

        // Set the type label to show type and percentage
        typeLabel.text = "\(detectedType): \(percentage)"
        typeLabel.isHidden = false

        // Set appropriate sizes based on detected type
        if detectedType == "Shoes" {
            currentSizes = shoeSizes
        } else {
            currentSizes = clothingSizes
        }
        
        // Setup size table view
        sizeTableView.delegate = self
        sizeTableView.dataSource = self
        sizeTableView.reloadData()
        
        // Setup size dropdown button
        sizeDropdownButton.addTarget(self, action: #selector(toggleSizeDropdown), for: .touchUpInside)
        
        // Add modal background and modal view
        view.addSubview(modalBackground)
        view.addSubview(modalView)
        
        // Add subviews to modalView
        modalView.addSubview(closeButton)
        modalView.addSubview(typeLabel)
        modalView.addSubview(brandTextField)
        modalView.addSubview(sizeLabel)
        modalView.addSubview(sizeDropdownButton)
        modalView.addSubview(sizeTableView)
        modalView.addSubview(saveButton)
        
        // Add button targets
        closeButton.addTarget(self, action: #selector(dismissModal), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveItem), for: .touchUpInside)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Background constraints
            modalBackground.topAnchor.constraint(equalTo: view.topAnchor),
            modalBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            modalBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            modalBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Modal view constraints
            modalView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modalView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            modalView.widthAnchor.constraint(equalToConstant: 300),
            modalView.heightAnchor.constraint(equalToConstant: 450),
            
            // Close button constraints
            closeButton.topAnchor.constraint(equalTo: modalView.topAnchor, constant: 10),
            closeButton.trailingAnchor.constraint(equalTo: modalView.trailingAnchor, constant: -10),
            
            // Type label constraints
            typeLabel.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 20),
            typeLabel.leadingAnchor.constraint(equalTo: modalView.leadingAnchor, constant: 20),
            typeLabel.trailingAnchor.constraint(equalTo: modalView.trailingAnchor, constant: -20),
            
            // Brand text field constraints
            brandTextField.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 40),
            brandTextField.leadingAnchor.constraint(equalTo: modalView.leadingAnchor, constant: 20),
            brandTextField.trailingAnchor.constraint(equalTo: modalView.trailingAnchor, constant: -20),
            brandTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // Size label constraints
            sizeLabel.topAnchor.constraint(equalTo: brandTextField.bottomAnchor, constant: 40),
            sizeLabel.leadingAnchor.constraint(equalTo: modalView.leadingAnchor, constant: 20),
            sizeLabel.widthAnchor.constraint(equalToConstant: 50),
            sizeLabel.heightAnchor.constraint(equalToConstant: 30),
            
            // Size dropdown button constraints
            sizeDropdownButton.centerYAnchor.constraint(equalTo: sizeLabel.centerYAnchor),
            sizeDropdownButton.leadingAnchor.constraint(equalTo: sizeLabel.trailingAnchor, constant: 20),
            sizeDropdownButton.trailingAnchor.constraint(equalTo: modalView.trailingAnchor, constant: -30),
            sizeDropdownButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Size table view constraints - Updated positioning
            sizeTableView.topAnchor.constraint(equalTo: sizeDropdownButton.bottomAnchor),
            sizeTableView.leadingAnchor.constraint(equalTo: sizeDropdownButton.leadingAnchor),
            sizeTableView.trailingAnchor.constraint(equalTo: sizeDropdownButton.trailingAnchor),
            sizeTableView.heightAnchor.constraint(equalToConstant: 200),
            
            saveButton.bottomAnchor.constraint(equalTo: modalView.bottomAnchor, constant: -20),
            saveButton.centerXAnchor.constraint(equalTo: modalView.centerXAnchor),
            saveButton.widthAnchor.constraint(equalTo: modalView.widthAnchor, multiplier: 0.8),
            saveButton.heightAnchor.constraint(equalToConstant: 50)
            
        ])
    }
    
    private func updateInterfaceColors() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        
        modalView.backgroundColor = isDarkMode ? .black : .white
        
        sizeDropdownButton.backgroundColor = isDarkMode ? .darkGray : .white
        sizeDropdownButton.setTitleColor(isDarkMode ? .white : .black, for: .normal)
        sizeDropdownButton.layer.borderColor = isDarkMode ? UIColor.white.cgColor : UIColor.black.cgColor
        
        sizeTableView.backgroundColor = isDarkMode ? .darkGray : .white
        sizeTableView.layer.borderColor = isDarkMode ? UIColor.white.cgColor : UIColor.black.cgColor
        
        brandTextField.backgroundColor = isDarkMode ? .darkGray : .white
        brandTextField.textColor = isDarkMode ? .white : .black

        typeLabel.textColor = .label
        sizeLabel.textColor = .label
            
        // Update font sizes for better visibility
        typeLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        sizeDropdownButton.titleLabel?.font = .systemFont(ofSize: 18)
    }
    
    // Add toggle function for size dropdown
    @objc private func toggleSizeDropdown() {
        if sizeTableView.isHidden {
            // Bring table view to front when showing
            modalView.bringSubviewToFront(sizeTableView)
            sizeTableView.isHidden = false
            sizeTableView.alpha = 0
            UIView.animate(withDuration: 0.2) {
                self.sizeTableView.alpha = 1
            }
            sizeDropdownButton.setTitle(sizeDropdownButton.title(for: .normal)?.replacingOccurrences(of: "▼", with: "▲"), for: .normal)
        } else {
            UIView.animate(withDuration: 0.2) {
                self.sizeTableView.alpha = 0
            } completion: { _ in
                self.sizeTableView.isHidden = true
                // Bring save button to front when dropdown is hidden
                self.modalView.bringSubviewToFront(self.saveButton)
            }
            sizeDropdownButton.setTitle(sizeDropdownButton.title(for: .normal)?.replacingOccurrences(of: "▲", with: "▼"), for: .normal)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        view.endEditing(true)  // This dismisses the keyboard
        if !sizeTableView.isHidden {
            toggleSizeDropdown()
        }
    }

    // 6. Add UITextFieldDelegate method
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    @objc private func dismissModal() {
        UIView.animate(withDuration: 0.3, animations: {
            self.modalBackground.alpha = 0
            self.modalView.alpha = 0
        }) { _ in
            self.modalBackground.isHidden = true
            self.modalView.isHidden = true
            self.modalBackground.removeFromSuperview()
            self.modalView.removeFromSuperview()
        }
    }

    @objc private func saveItem() {
        let selectedSize = sizeDropdownButton.title(for: .normal)?.replacingOccurrences(of: " ▼", with: "").replacingOccurrences(of: " ▲", with: "") ?? "Select Size"
        // Validate size selection
        guard selectedSize != "Select Size" else {
            showAlert(message: "Please select a size")
            return
        }
        
        guard let brand = brandTextField.text, !brand.isEmpty,
              let type = resultLabel.text?.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces),
              let currentImage = self.currentImage,
              let imageData = currentImage.pngData() else {
            showAlert(message: "Please fill in all fields")
            return
        }
        
        guard let currentUser = Auth.auth().currentUser else {
            showAlert(message: "You need to be signed in to add an item")
            return
        }
        
        // Show loading indicator
        let loadingAlert = UIAlertController(title: nil, message: "Saving...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        // Upload image to Firebase Storage
        let fileName = "\(UUID().uuidString).png"
        let storageRef = Storage.storage().reference()
            .child("images")
            .child(currentUser.uid)
            .child(fileName)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/png"
        
        storageRef.putData(imageData, metadata: metadata) { [weak self] metadata, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        self.showAlert(message: "Error uploading image: \(error.localizedDescription)")
                    }
                }
                return
            }
            
            // Get download URL
            storageRef.downloadURL { url, error in
                if let error = error {
                    DispatchQueue.main.async {
                        loadingAlert.dismiss(animated: true) {
                            self.showAlert(message: "Error getting download URL: \(error.localizedDescription)")
                        }
                    }
                    return
                }
                
                guard let downloadURL = url else {
                    DispatchQueue.main.async {
                        loadingAlert.dismiss(animated: true) {
                            self.showAlert(message: "Error: Could not get download URL")
                        }
                    }
                    return
                }
                
                // Save to Firestore
                let userRef = self.db.collection("users").document(currentUser.uid)
                
                let photoData: [String: Any] = [
                    "url": downloadURL.absoluteString,
                    "timestamp": ISO8601DateFormatter().string(from: Date()),
                    "size": selectedSize,
                    "type": type,
                    "brand": brand,
                    "rgbValues": [
                        "red": self.rgbValues.red,
                        "green": self.rgbValues.green,
                        "blue": self.rgbValues.blue
                    ],
                    "rejectionCount": 0
                ]
                
                userRef.updateData([
                    "photoArray": FieldValue.arrayUnion([photoData]),
                    "updatedAt": FieldValue.serverTimestamp()
                ]) { error in
                    DispatchQueue.main.async {
                        loadingAlert.dismiss(animated: true) {
                            if let error = error {
                                self.showAlert(message: "Error saving data: \(error.localizedDescription)")
                            } else {
                                // Success - clear fields and dismiss
                                self.sizePicker.selectRow(0, inComponent: 0, animated: false)
                                self.brandTextField.text = ""
                                self.dismissModal()
                                
                                self.showAlert(message: "Item saved successfully!") {
                                    self.retakeButtonTapped()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
          
    private func analyzeColors(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            print("Failed to get CGImage")
            return
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var rawData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            print("Failed to create context")
            return
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var totalR: Int = 0
        var totalG: Int = 0
        var totalB: Int = 0
        var pixelCount: Int = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                let alpha = rawData[offset + 3]
                
                if alpha > 0 {
                    totalR += Int(rawData[offset])
                    totalG += Int(rawData[offset + 1])
                    totalB += Int(rawData[offset + 2])
                    pixelCount += 1
                }
            }
        }
        
        if pixelCount > 0 {
            let avgR = Double(totalR) / Double(pixelCount)
            let avgG = Double(totalG) / Double(pixelCount)
            let avgB = Double(totalB) / Double(pixelCount)
            
            self.rgbValues = (avgR, avgG, avgB)
            print("RGB: [\(avgR), \(avgG), \(avgB)]")
        }
    }
    
    private func rgbToHsv(r: Float, g: Float, b: Float) -> (h: Float, s: Float, v: Float) {
        let cmax = max(r, g, b)
        let cmin = min(r, g, b)
        let diff = cmax - cmin
        
        var h: Float = 0
        var s: Float = 0
        let v = cmax
        
        if cmax != 0 {
            s = diff / cmax
        }
        
        if diff != 0 {
            switch cmax {
            case r: h = (g - b) / diff + (g < b ? 6 : 0)
            case g: h = (b - r) / diff + 2
            case b: h = (r - g) / diff + 4
            default: break
            }
            h /= 6
        }
        
        return (h * 360, s * 100, v * 100)
    }
    
    private func showAlert(message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(
            title: "Alert",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
    
}



// MARK: - AVCapturePhotoCaptureDelegate
extension ImageClassifierViewController {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              var image = UIImage(data: imageData) else {
            return
        }
        
        // Fix orientation
        if image.imageOrientation != .up {
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            image.draw(in: CGRect(origin: .zero, size: image.size))
            if let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() {
                UIGraphicsEndImageContext()
                image = normalizedImage
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Set the captured image
            self.currentImage = image
            self.imageView.image = image
            
            // Update UI visibility
            self.imageView.isHidden = false
            self.previewView.isHidden = true
            self.captureButton.isHidden = true
            self.retakeButton.isHidden = false
            
            // Add overlay label instruction
            let instructionLabel = UILabel()
            instructionLabel.translatesAutoresizingMaskIntoConstraints = false
            instructionLabel.text = "Draw a rectangle around the item"
            instructionLabel.textColor = .white
            instructionLabel.textAlignment = .center
            instructionLabel.backgroundColor = .black.withAlphaComponent(0.7)
            instructionLabel.layer.cornerRadius = 10
            instructionLabel.layer.masksToBounds = true
            instructionLabel.font = .systemFont(ofSize: 16, weight: .medium)
            
            self.view.addSubview(instructionLabel)
            
            NSLayoutConstraint.activate([
                instructionLabel.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                instructionLabel.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 20),
                instructionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: self.view.leadingAnchor, constant: 20),
                instructionLabel.trailingAnchor.constraint(lessThanOrEqualTo: self.view.trailingAnchor, constant: -20),
                instructionLabel.heightAnchor.constraint(equalToConstant: 40)
            ])
            
            // Animate instruction label
            instructionLabel.alpha = 0
            UIView.animate(withDuration: 0.3) {
                instructionLabel.alpha = 1
            }
            
            // Remove instruction label after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                UIView.animate(withDuration: 0.3) {
                    instructionLabel.alpha = 0
                } completion: { _ in
                    instructionLabel.removeFromSuperview()
                }
            }
        }
    }
}

// MARK: - UIImage Extension
extension UIImage {
    func toCVPixelBuffer(size: CGSize) -> CVPixelBuffer? {
        // First scale the image while maintaining aspect ratio
        let scale: CGFloat
        if size.width / size.height > self.size.width / self.size.height {
            scale = size.height / self.size.height
        } else {
            scale = size.width / self.size.width
        }
        
        let scaledWidth = self.size.width * scale
        let scaledHeight = self.size.height * scale
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: scaledWidth, height: scaledHeight), false, 1.0)
        self.draw(in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Create pixel buffer
        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                    kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                       Int(size.width),
                                       Int(size.height),
                                       kCVPixelFormatType_32BGRA,
                                       attrs,
                                       &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                              width: Int(size.width),
                              height: Int(size.height),
                              bitsPerComponent: 8,
                              bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        
        guard let cgContext = context else {
            return nil
        }
        
        // Draw in the center of the pixel buffer
        let drawX = (size.width - scaledWidth) / 2
        let drawY = (size.height - scaledHeight) / 2
        cgContext.draw(resizedImage?.cgImage ?? self.cgImage!, in: CGRect(x: drawX, y: drawY, width: scaledWidth, height: scaledHeight))
        
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return buffer
    }
}

// MARK: - SwiftUI Wrapper
struct CameraViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ImageClassifierViewController {
        return ImageClassifierViewController()
    }
    
    func updateUIViewController(_ uiViewController: ImageClassifierViewController, context: Context) {
        // Update if needed
    }
}
