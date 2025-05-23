//
//  DraggedActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/5/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI

extension GraphState {
    /**
     User dragged, pressed or tapped a layer in the preview window.
     (i.e. SwiftUI view corresponding to a layer node, visible in the prototype preview window)

     Dispatched from SwiftUI DragGesture.onChanged;
     handles drag, scroll and press interactions.
     */
    @MainActor
    func layerDragged(interactiveLayer: InteractiveLayer,
                      location: CGPoint,
                      translation: CGSize,
                      velocity: CGSize,
                      parentSize: CGSize,
                      childSize: CGSize) {
                
        guard let previewWindowSize = self.documentDelegate?.previewWindowSize else {
            fatalErrorIfDebug("layerDragEnded: Must have preview window size")
            return
        }
        
        // log("layerDragged CALLED")
        
        var nodesToRecalculate = NodeIdSet()

        let dragInteractionIdSet: IdSet = self.getDragInteractionIds(for: interactiveLayer.id.layerNodeId)

        let scrollInteractionIdSet: IdSet = self.getScrollInteractionIds(for: interactiveLayer.id.layerNodeId)
        
        let pressInteractionIdSet: IdSet = self.getPressInteractionIds(for: interactiveLayer.id.layerNodeId)

        let mouseNodeIds: NodeIdSet = self.mouseNodes
        
        // Set child and parent size of interactive layer--scroll interaction uses this
        interactiveLayer.childSize = childSize
        interactiveLayer.parentSize = parentSize

        self.documentDelegate?.updateMouseNodesPosition(mouseNodeIds: mouseNodeIds,
                                                        gestureLocation: location,
                                                        velocity: velocity.toCGPoint,
                                                        leftClick: true,
                                                        previewWindowSize: previewWindowSize,
                                                        graphTime: self.graphStepState.graphTime)
        
        nodesToRecalculate = nodesToRecalculate.union(mouseNodeIds)
        
        // Manages translation and velcoity state for layer
        interactiveLayer.layerInteracted(
            translation: translation,
            velocity: velocity,
            tapLocation: location)

        // e.g. `pressInteractionIdSet` may be empty, so it's fine to add an empty set.
        nodesToRecalculate = nodesToRecalculate.union(pressInteractionIdSet)
        nodesToRecalculate = nodesToRecalculate.union(dragInteractionIdSet)
        nodesToRecalculate = nodesToRecalculate.union(scrollInteractionIdSet)
        
        if !dragInteractionIdSet.isEmpty {
            
            self.activeDragInteraction.activeDragInteractionNodes = self.activeDragInteraction.activeDragInteractionNodes.union(dragInteractionIdSet)
            
            for dragInteractionId in dragInteractionIdSet {
                if let node = self.getNode(id: dragInteractionId),
                   node.isDragNodeEnabled {
                    nodesToRecalculate.insert(node.id)
                } // if let node
            } // for
        } // if
        
        self.scheduleForNextGraphStep(nodesToRecalculate)
    }
}
