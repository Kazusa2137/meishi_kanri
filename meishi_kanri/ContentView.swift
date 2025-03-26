import SwiftUI
import UIKit
import TOCropViewController

struct ContentView: View {
    @State private var selectedImages: [UIImage] = [] // 複数の画像を保持する配列
    @State private var showImagePicker: Bool = false
    @State private var isCamera: Bool = true // カメラのみ有効にする
    
    var body: some View {
        NavigationView {
            VStack {
                // 選ばれた画像があれば表示
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                        ForEach(selectedImages.indices, id: \.self) { index in
                            // 画像タップで拡大表示
                            NavigationLink(destination: ImageDetailView(image: selectedImages[index])) {
                                Image(uiImage: selectedImages[index])
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 150, height: 150)
                                    .cornerRadius(10)
                                    .padding(5)
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
            .navigationTitle("名刺管理")
        }
    }
}

struct ImageDetailView: View {
    var image: UIImage
    
    var body: some View {
        VStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding()
                .navigationTitle("拡大画像")
                .navigationBarTitleDisplayMode(.inline)
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
