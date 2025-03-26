import SwiftUI
import UIKit
import TOCropViewController

struct ContentView: View {
    @State private var selectedImages: [UIImage] = [] // 複数の画像を保持する配列
    @State private var showImagePicker: Bool = false
    @State private var isCamera: Bool = true // カメラのみ有効にする
    
    var body: some View {
        VStack {
            // 選ばれた画像があれば表示
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                    ForEach(selectedImages.indices, id: \.self) { index in
                        ZStack {
                            Image(uiImage: selectedImages[index])
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 150)
                                .cornerRadius(10)
                                .padding(5)
                            
                            // 削除ボタン
                            Button(action: {
                                showDeleteConfirmation(index: index)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .padding(5)
                                    .background(Color.white.opacity(0.7))
                                    .clipShape(Circle())
                                    .offset(x: 50, y: -50)
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
                ImagePicker(selectedImages: $selectedImages, isCamera: isCamera)
            }
        }
        .padding()
    }
    
    // 画像削除の確認ダイアログ
    func showDeleteConfirmation(index: Int) {
        let alertController = UIAlertController(title: "削除の確認", message: "本当にこの画像を削除しますか？", preferredStyle: .alert)
        
        // 削除アクション
        alertController.addAction(UIAlertAction(title: "削除", style: .destructive, handler: { _ in
            selectedImages.remove(at: index) // 画像を削除
        }))
        
        // キャンセルアクション
        alertController.addAction(UIAlertAction(title: "キャンセル", style: .cancel, handler: nil))
        
        // 現在のViewControllerでアラートを表示
        if let rootVC = UIApplication.shared.windows.first?.rootViewController {
            rootVC.present(alertController, animated: true, completion: nil)
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    var isCamera: Bool
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(selectedImages: $selectedImages)
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
        @Binding var selectedImages: [UIImage]
        
        init(selectedImages: Binding<[UIImage]>) {
            _selectedImages = selectedImages
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
            selectedImages.append(croppedImage) // トリミングされた画像を追加
            controller.dismiss(animated: true)
        }
        
        // キャンセルされた時の処理
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
