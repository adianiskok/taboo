//
//  ARUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 11/29/22.
//

import ARKit
import RealityKit
import simd
import StitchSchemaKit

extension Transform {
    /// Creates a matrix from scratch.
    static func createMatrix(positionX: Float,
                             positionY: Float,
                             positionZ: Float,
                             scaleX: Float,
                             scaleY: Float,
                             scaleZ: Float,
                             rotationX: Float,
                             rotationY: Float,
                             rotationZ: Float,
                             rotationReal: Float) -> Transform {
        let position = SIMD3([positionX, positionY, positionZ])
        let scale = SIMD3([scaleX, scaleY, scaleZ])
        
        let rotation = SIMD3([rotationZ, rotationY, rotationX])
        
        let matrix = simd_float4x4(position: position,
                                   scale: scale,
                                   rotationZYX: rotation)
        
        return .init(matrix: matrix)
    }

    var position: SCNVector3 {
        self.matrix.position
    }
}

extension matrix_float4x4: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.hashValue)
    }
}

//extension matrix_float4x4 {
//    var position: SCNVector3 {
//        SCNVector3(columns.3.x, columns.3.y, columns.3.z)
//    }
//
//    var orientation: simd_quatf {
//        simd_quaternion(self)
//    }
//
//    var rotation: simd_quatf {
//        let qw = sqrt(1 + columns.0.x + columns.1.y + columns.2.z) / 2
//        let qx = (columns.2.y - columns.1.z) / (4 * qw)
//        let qy = (columns.0.z - columns.2.x) / (4 * qw)
//        let qz = (columns.1.x - columns.0.y) / (4 * qw)
//        return simd_quatf(ix: qx, iy: qy, iz: qz, r: qw)
//    }
//
//    var scale: SCNVector3 {
//        get {
//            SCNVector3(columns.0.x, columns.1.y, columns.2.z)
//        }
//        set(newvalue) {
//            self.columns.0.x = newvalue.x
//            self.columns.1.y = newvalue.y
//            self.columns.2.z = newvalue.z
//        }
//    }
//}

extension SCNVector3 {
    static func==(lhs: SCNVector3, rhs: SCNVector3) -> Bool {
        lhs.x == rhs.x &&
            lhs.y == rhs.y &&
            lhs.z == rhs.z
    }
}

extension Entity {
    // MARK: eval logic for model 3D patch node
    func _applyMatrix(newMatrix: matrix_float4x4) {
        self.transform.matrix = newMatrix
    }
}

typealias EntitySequence = [Entity.ChildCollection.Element]

extension AnchorEntity {
    /// Finds and removes a sequence of entities from an `AnchorEntity`.
    func removeAllEntities(_ entities: EntitySequence) {
        entities.forEach { otherEntity in
            if let entityToRemove = self.findEntity(named: otherEntity.name) {
                self.removeChild(entityToRemove)
            }
        }
    }
}

extension StitchTransform {
    static let zero = DEFAULT_STITCH_TRANSFORM
    
    init(from matrix: simd_float4x4) {
        self.init(positionX: Double(matrix.position.x),
                  positionY: Double(matrix.position.y),
                  positionZ: Double(matrix.position.z),
                  scaleX: Double(matrix.scale.x),
                  scaleY: Double(matrix.scale.y),
                  scaleZ: Double(matrix.scale.z),
                  rotationX: Double(matrix.rotation.imag.x),
                  rotationY: Double(matrix.rotation.imag.y),
                  rotationZ: Double(matrix.rotation.imag.z))
    }
    
    var position3D: Point3D {
        .init(x: self.positionX,
              y: self.positionY,
              z: self.positionZ
        )
    }
    
    var scale3D: Point3D {
        .init(x: self.scaleX,
              y: self.scaleY,
              z: self.scaleZ
        )
    }
    
    var rotation3D: Point3D {
        .init(x: self.rotationX,
              y: self.rotationY,
              z: self.rotationZ
        )
    }
}
