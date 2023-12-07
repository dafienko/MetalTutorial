import MetalKit
import Spatial

struct ObjMaterial {
    var color: v3f = v3f(0.0, 0.0, 0.0)
}

func parseMaterials(mtlFile: URL) -> [String: ObjMaterial] {
    let data = try! String(contentsOf: mtlFile, encoding: .utf8)
    let lines = data.components(separatedBy: .newlines)

    var materials: [String: ObjMaterial] = [:]
    
    // ensure a default material exists
    materials[""] = ObjMaterial(color: v3f(1.0, 1.0, 1.0))
    
    var currentMaterialName: String?
    for line in lines {
        let materialComponents = line.components(separatedBy: " ").filter { !$0.isEmpty }
        if materialComponents.isEmpty {
            continue
        }
        
        switch materialComponents.first?.trimmingCharacters(in: .whitespaces) {
        case "newmtl":
            if materialComponents.count >= 2 {
                currentMaterialName = materialComponents[1]
                materials[currentMaterialName!] = ObjMaterial()
            }
        case "Kd":
            guard let name = currentMaterialName else { break }
            
            materials[name]!.color = v3f(
                Float(materialComponents[1])!,
                Float(materialComponents[2])!,
                Float(materialComponents[3])!
            )
        default:
            break
        }
    }
    
    return materials
}

struct ModelGeometry {
    var vertices: [Vertex] = []
    var indices: [UInt16] = []
    var maxBound: v3f
    var minBound: v3f
}

func parseVertices(objFile: URL, materials: [String: ObjMaterial]) -> ModelGeometry {
    let data = try! String(contentsOf: objFile, encoding: .utf8)
    let lines = data.components(separatedBy: .newlines)
    
    var vertices: [Vertex] = []
    var indices: [UInt16] = []
    
    var positions: [v3f] = []
    var normals: [v3f] = []
    var indexMap: [String: [SIMD2<Int>: UInt16]] = [:]
    var maxBound = v3f()
    var minBound = v3f()
    
    var currentMaterial: String = ""
    indexMap[currentMaterial] = [:]
    
    func parseLinev3f(components: [String]) -> v3f {
        return v3f(
            Float(components[1])!,
            Float(components[2])!,
            Float(components[3])!
        )
    }
    
    func parseFaceIndices(components: [String]) -> [UInt16] {
        var faceIndices: [UInt16] = []
        for i in 1..<components.count {
            let indexComponents = components[i].components(separatedBy: "/")
            let indexPair = SIMD2<Int>(
                Int(indexComponents[0])! - 1,
                Int(indexComponents.last!)! - 1
            )
            
            var index = indexMap[currentMaterial]![indexPair]
            if index == nil {
                index = UInt16(vertices.count)
                vertices.append(Vertex(
                    position: positions[indexPair.x],
                    normal: normals[indexPair.y],
                    color: materials[currentMaterial]!.color
                ))
                indexMap[currentMaterial]![indexPair] = index
            }
            
            faceIndices.append(index!)
        }
        
        return faceIndices
    }
    
    for line in lines {
        let components = line.components(separatedBy: " ").filter { !$0.isEmpty }
        
        if components.isEmpty {
            continue
        }
        
        switch components[0] {
        case "v":
            let pos = parseLinev3f(components: components)
            maxBound = v3f(max(maxBound.x, pos.x), max(maxBound.y, pos.y), max(maxBound.z, pos.z))
            minBound = v3f(min(minBound.x, pos.x), min(minBound.y, pos.y), min(minBound.z, pos.z))
            
            positions.append(pos)
        case "vn":
            normals.append(parseLinev3f(components: components))
        case "f":
            let faceIndices: [UInt16] = parseFaceIndices(components: components)
            if faceIndices.count == 3 { // triangle: append as-is
                indices.append(contentsOf: faceIndices)
            } else if faceIndices.count == 4 { // quad: break into triangles before appending
                indices.append(contentsOf: [
                    faceIndices[0], faceIndices[1], faceIndices[2],
                    faceIndices[0], faceIndices[2], faceIndices[3]
                ])
            }
        case "usemtl":
            currentMaterial = components.last!
            indexMap[currentMaterial] = [:]
        default:
            break
        }
    }
    
    return ModelGeometry(vertices: vertices, indices: indices, maxBound: maxBound, minBound: minBound)
}

class Model : NSObject {
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    var transform: float4x4 = float4x4(1.0)
    var indexCount: Int = 0
    
    init(device: MTLDevice, objFile: URL, mtlFile: URL) {
        super.init()
        
        let geometry = parseVertices(
            objFile: objFile,
            materials: parseMaterials(mtlFile: mtlFile)
        )
        indexCount = geometry.indices.count
        
        let scale = 20.0 / length(geometry.maxBound - geometry.minBound)
        let center = ((geometry.maxBound + geometry.minBound) / 2.0) * scale
        transform *= simd_float4x4(AffineTransform3D.init(translation: Vector3D(x: -center.x, y: -center.y, z: -25.0 - center.z)))
        transform *= simd_float4x4(AffineTransform3D.init(scale: Size3D(width: scale, height: scale, depth: scale)))
        
        vertexBuffer = device.makeBuffer(
            bytes: geometry.vertices,
            length: geometry.vertices.count * MemoryLayout<Vertex>.stride,
            options: []
        )
        
        indexBuffer = device.makeBuffer(
            bytes: geometry.indices,
            length: geometry.indices.count * MemoryLayout<UInt16>.size,
            options: []
        )
    }
    
    func render(encoder: MTLRenderCommandEncoder, viewMatrix: float4x4, projectionMatrix: float4x4) {
        guard
            let vertexBuffer = vertexBuffer,
            let indexBuffer = indexBuffer
        else { return }
    
        transform *= simd_float4x4(AffineTransform3D.init(rotation: Rotation3D(eulerAngles: EulerAngles(angles: simd_float3(0, 0.01, 0), order: .xyz))))
        var uniforms = Uniforms(modelMatrix: viewMatrix * transform, projMatrix: projectionMatrix)
        
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 1)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexCount,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
    }
}
