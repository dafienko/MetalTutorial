import UIKit
import MetalKit
import Spatial

typealias v3f = SIMD3<Float>

struct Uniforms {
    var modelMatrix: float4x4 = float4x4(1.0)
    var projMatrix: float4x4 = float4x4(1.0)
}

struct Vertex {
    var position: v3f
    var normal: v3f
    var color: v3f
}

class ViewController: UIViewController {
    @IBOutlet weak var metalView: MTKView!

    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState?
    var depthStencilState: MTLDepthStencilState?
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    
    let vertices = [
        Vertex(position: v3f(0.0, 1.0, 0.0), normal: v3f(0, 0, 1.0), color: v3f(1.0, 0.0, 0.0)),
        Vertex(position: v3f(-1.0, -1.0, 0.0), normal: v3f(0, 0, 1.0), color: v3f(0.0, 1.0, 0.0)),
        Vertex(position: v3f(1.0, -1.0, 0.0), normal: v3f(0, 0, 1.0), color: v3f(0.0, 0.0, 1.0)),
    ]
    
    let indices: [UInt16] = [0, 1, 2]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let device = MTLCreateSystemDefaultDevice()!
        metalView.device = device
        metalView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
        metalView.delegate = self
        
        commandQueue = metalView.device?.makeCommandQueue();
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = MemoryLayout<v3f>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        vertexDescriptor.attributes[2].format = .float3
        vertexDescriptor.attributes[2].offset = vertexDescriptor.attributes[1].offset + MemoryLayout<v3f>.stride
        vertexDescriptor.attributes[2].bufferIndex = 0
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        
        let library = device.makeDefaultLibrary()
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library?.makeFunction(name: "vertex_shader")
        pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "fragment_shader")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
        
        vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Vertex>.stride,
            options: []
        )
        
        indexBuffer = device.makeBuffer(
            bytes: indices,
            length: indices.count * MemoryLayout<UInt16>.size,
            options: []
        )
    }
}

extension ViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }
    
    func draw(in view: MTKView) {
        let buffer = commandQueue.makeCommandBuffer()!
        let encoder = buffer.makeRenderCommandEncoder(descriptor: metalView.currentRenderPassDescriptor!)!
        
        var uniforms = Uniforms(
            modelMatrix: float4x4(AffineTransform3D(translation: Vector3D(x: 0.0, y: 0.0, z: -10.0))),
            projMatrix: float4x4(ProjectiveTransform3D(
                fovyRadians: 45.0 * (Double.pi / 180.0),
                aspectRatio: view.drawableSize.width / view.drawableSize.height,
                nearZ: 0.1,
                farZ: 100.0)
            )
        )
        
        encoder.setDepthStencilState(depthStencilState!)
        encoder.setRenderPipelineState(pipelineState!)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 1)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indices.count,
            indexType: .uint16,
            indexBuffer: indexBuffer!,
            indexBufferOffset: 0
        )
        
        encoder.endEncoding()
        buffer.present(view.currentDrawable!)
        buffer.commit()
    }
}
