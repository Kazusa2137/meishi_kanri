import SwiftUI
import UIKit
import TOCropViewController
import Vision
import Foundation

struct BusinessCardInfo {
    var company: String?
    var name: String?
    var phoneNumber: String?
    var email: String?
}

func extractBusinessCardInfo(from text: String) -> BusinessCardInfo {
    var extractedInfo = BusinessCardInfo()
    
    let lines = text.components(separatedBy: "\n")
    
    // **最初の行を会社名として認識**
    if let firstLine = lines.first {
        extractedInfo.company = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // **次の行を名前として認識**
    if lines.count > 1 {
        extractedInfo.name = lines[1].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // **メールアドレスの正規表現**
    let emailRegex = try! NSRegularExpression(pattern: "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}", options: .caseInsensitive)
    if let match = emailRegex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
        extractedInfo.email = (text as NSString).substring(with: match.range)
    }

    // **電話番号の正規表現（例: 080-1234-5678 や 03-1234-5678）**
    let phoneRegex = try! NSRegularExpression(pattern: "\\d{2,4}-\\d{2,4}-\\d{4}", options: [])
    if let match = phoneRegex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
        extractedInfo.phoneNumber = (text as NSString).substring(with: match.range)
    }

    return extractedInfo
}

struct ContentView: View {
    @State private var selectedImages: [(image: UIImage, annotation: String)] = [] // 画像と注釈を保持する配列
    @State private var showImagePicker: Bool = false
    @State private var isCamera: Bool = true // カメラのみ有効にする
    @State private var isFrontImageCaptured: Bool = false // 表面の撮影が終わったかのフラグ
    
    var body: some View {
        NavigationView {
            VStack {
                // 選ばれた画像があれば表示
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                        ForEach(selectedImages.indices, id: \.self) { index in
                            VStack {
                                // 画像タップで拡大表示
                                NavigationLink(destination: ImageDetailView(imageData: $selectedImages[index], index: index, deleteImageAction: deleteImage)) {
                                    Image(uiImage: selectedImages[index].image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 150, height: 150)
                                        .cornerRadius(10)
                                        .padding(5)
                                }
                                
                                // 削除ボタン
                                Button(action: {
                                    deleteImage(at: index)
                                }) {
                                    Text("削除")
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                        .padding(5)
                                }
                            }
                        }
                    }
                }
                
                // 画像選択ボタン
                Button("名刺を撮影") {
                    // カメラ起動
                    showImagePicker.toggle()
                }
                .padding()
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker(selectedImages: $selectedImages, isCamera: isCamera, isFrontImageCaptured: $isFrontImageCaptured)
                }
            }
            .navigationTitle("名刺管理")
        }
    }
    
    func deleteImage(at index: Int) {
        // 削除前に確認のアラートを表示
        let alert = UIAlertController(title: "確認", message: "本当に削除しますか？", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "削除", style: .destructive, handler: { _ in
            // 削除処理
            selectedImages.remove(at: index)
        }))
        
        // アラートを表示
        if let rootVC = UIApplication.shared.windows.first?.rootViewController {
            rootVC.present(alert, animated: true, completion: nil)
        }
    }
}

struct ImageDetailView: View {
    @Binding var imageData: (image: UIImage, annotation: String)
    var index: Int
    @State private var editedAnnotation: String
    @State private var showAlert: Bool = false // アラートを表示するための状態
    var deleteImageAction: (Int) -> Void  // 削除ボタンのアクション
    
    init(imageData: Binding<(image: UIImage, annotation: String)>, index: Int, deleteImageAction: @escaping (Int) -> Void) {
        self._imageData = imageData
        self.index = index
        self.deleteImageAction = deleteImageAction
        _editedAnnotation = State(initialValue: imageData.wrappedValue.annotation)
    }
    
    var body: some View {
        VStack {
            Image(uiImage: imageData.image)
                .resizable()
                .scaledToFit()
                .padding()
                .navigationTitle("拡大画像")
                .navigationBarTitleDisplayMode(.inline)
            
            // テキストフィールドで注釈を編集
            TextEditor(text: $editedAnnotation)  // TextFieldからTextEditorに変更
                .padding()
                .frame(height: 200)
                .border(Color.gray, width: 1)
                .padding(.horizontal)
            
            // 保存ボタン
            Button("保存") {
                // 入力した注釈を保存
                imageData.annotation = editedAnnotation
                showAlert = true // 保存後にアラートを表示
            }
            .padding()
            .foregroundColor(.blue)
            
            // 削除ボタン
            Button(action: {
                // 削除処理を呼び出す
                deleteImageAction(index)
            }) {
                Text("削除")
                    .font(.title2)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("保存しました"), message: nil, dismissButton: .default(Text("OK")))
        }
        .onAppear {
            // 画像からテキストを認識する
            recognizeText(from: imageData.image)
        }
    }
    
    func recognizeText(from image: UIImage) {
        // Visionのリクエストを使って画像内のテキストを認識する
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil else {
                print("テキスト認識エラー: \(String(describing: error))")
                return
            }
            
            // 認識されたテキストを処理
            if let observations = request.results as? [VNRecognizedTextObservation] {
                let recognizedText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                
                DispatchQueue.main.async {
                    // 🔹 名刺情報を抽出
                    let extractedInfo = extractBusinessCardInfo(from: recognizedText)
                    
                    // 🔹 不明の時のデフォルト値を適用し、改行を追加
                    self.editedAnnotation = """
                    会社（職業）: \(extractedInfo.company ?? "不明")
                    名前: \(extractedInfo.name ?? "不明")
                    電話: \(extractedInfo.phoneNumber ?? "不明")
                    メール: \(extractedInfo.email ?? "不明")
                    """
                }
            }
        }
        
        // 日本語を指定してリクエストを作成
        request.recognitionLanguages = ["ja-JP", "en-US"]  // 日本語対応
        
        // リクエストを実行する
        let handler = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("テキスト認識の実行エラー: \(error)")
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [(image: UIImage, annotation: String)]
    var isCamera: Bool
    @Binding var isFrontImageCaptured: Bool
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(selectedImages: $selectedImages, isFrontImageCaptured: $isFrontImageCaptured)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        
        // カメラのみ選択
        picker.sourceType = .camera
        picker.allowsEditing = false // 編集はTOCropViewControllerで行う
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // 必要に応じて更新処理
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate, TOCropViewControllerDelegate {
        @Binding var selectedImages: [(image: UIImage, annotation: String)]
        @Binding var isFrontImageCaptured: Bool
        
        init(selectedImages: Binding<[(image: UIImage, annotation: String)]>, isFrontImageCaptured: Binding<Bool>) {
            _selectedImages = selectedImages
            _isFrontImageCaptured = isFrontImageCaptured
        }
        
        // 画像が選ばれた時の処理（撮影後）
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let selectedImage = info[.originalImage] as? UIImage {
                // TOCropViewControllerでトリミング編集
                let cropViewController = TOCropViewController(image: selectedImage)
                cropViewController.delegate = self
                picker.pushViewController(cropViewController, animated: true)
            }
        }
        
        // TOCropViewControllerでトリミングが終了した時の処理
        func cropViewController(_ controller: TOCropViewController, didCropTo croppedImage: UIImage, with cropRect: CGRect, angle: Int) {
            if isFrontImageCaptured {
                // 裏面が撮影された場合
                self.selectedImages.append((image: croppedImage, annotation: ""))
            } else {
                // 表面が撮影された場合
                self.selectedImages.append((image: croppedImage, annotation: ""))
                isFrontImageCaptured = true
            }
            controller.dismiss(animated: true)
        }
        
        // キャンセルされた時の処理
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
