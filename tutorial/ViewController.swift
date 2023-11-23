import UIKit
import MetalKit

class ViewController: UIViewController {
    @IBOutlet weak var metalView: MTKView!

    var commandQueue: MTLCommandQueue!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
        metalView.delegate = self
        
        commandQueue = metalView.device?.makeCommandQueue();
    }
}

extension ViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }
    
    func draw(in view: MTKView) {
        let buffer = commandQueue.makeCommandBuffer()!
        let encoder = buffer.makeRenderCommandEncoder(descriptor: metalView.currentRenderPassDescriptor!)!
        encoder.endEncoding()
        buffer.present(view.currentDrawable!)
        buffer.commit()
    }
}
