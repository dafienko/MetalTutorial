import UIKit
import MetalKit

class ViewController: UIViewController {
    @IBOutlet weak var metalView: MTKView!

    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState?
    var vertexBuffer: MTLBuffer?
    
    let vertices = [
        SIMD3<Float>(0.0, 1.0, 0.0),
        SIMD3<Float>(-1.0, -1.0, 0.0),
        SIMD3<Float>(1.0, -1.0, 0.0),
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let device = MTLCreateSystemDefaultDevice()!
        metalView.device = device
        metalView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
        metalView.delegate = self
        
        commandQueue = metalView.device?.makeCommandQueue();
        
        let library = device.makeDefaultLibrary()
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library?.makeFunction(name: "vertex_shader")
        pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "fragment_shader")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<SIMD3<Float>>.stride,
            options: []
        )
    }
}

extension ViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }
    
    func draw(in view: MTKView) {
        let buffer = commandQueue.makeCommandBuffer()!
        let encoder = buffer.makeRenderCommandEncoder(descriptor: metalView.currentRenderPassDescriptor!)!
        
        encoder.setRenderPipelineState(pipelineState!)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: vertices.count
        )
        
        encoder.endEncoding()
        buffer.present(view.currentDrawable!)
        buffer.commit()
    }
}
