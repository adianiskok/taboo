//
//  StitchComponentViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/4/24.
//

import SwiftUI
import StitchSchemaKit
import StitchEngine

/// Unique instance of a component
final class StitchComponentViewModel: Sendable {
    @MainActor var componentId: UUID
    
    @MainActor var inputsObservers: [InputNodeRowObserver] = []
    @MainActor var outputsObservers: [OutputNodeRowObserver] = []
    
    let canvas: CanvasItemViewModel
    let graph: GraphState
    
    @MainActor weak var nodeDelegate: NodeViewModel?
    @MainActor weak var componentDelegate: StitchMasterComponent?
    
    @MainActor
    init(nodeId: UUID,
         componentEntity: ComponentEntity,
         graph: GraphState,
         nodeDelegate: NodeViewModel? = nil,
         componentDelegate: StitchMasterComponent? = nil) {
        self.componentId = componentEntity.componentId
        self.graph = graph
        self.nodeDelegate = nodeDelegate
        self.componentDelegate = componentDelegate
        
        let inputsObservers = Self.refreshInputs(schemaInputs: componentEntity.inputs,
                                                 graph: graph,
                                                 nodeId: nodeId,
                                                 existingInputsObservers: [])
        let outputsObservers = Self.refreshOutputs(graph: graph,
                                                   nodeId: nodeId,
                                                   existingOutputsObservers: [])

        self.canvas = .init(from: componentEntity.canvasEntity,
                            id: .node(nodeId),
                            inputRowObservers: inputsObservers,
                            outputRowObservers: outputsObservers)
            
        self.inputsObservers = inputsObservers
        self.outputsObservers = outputsObservers
    }
    
    @MainActor
    func refreshPorts(schemaInputs: [NodeConnectionType]? = nil,
                      activeIndex: ActiveIndex) {
        let schemaInputs = schemaInputs ?? self.createSchema().inputs
        
        self.inputsObservers = self.refreshInputs(schemaInputs: schemaInputs)
        self.outputsObservers = self.refreshOutputs()
        self.canvas.syncRowViewModels(inputRowObservers: inputsObservers,
                                      outputRowObservers: outputsObservers,
                                      activeIndex: activeIndex)
    }
    
    // TODO: what is this ?
    @MainActor
    func refreshInputs(schemaInputs: [NodeConnectionType]) -> [InputNodeRowObserver] {
        Self.refreshInputs(schemaInputs: schemaInputs,
                           graph: self.graph,
                           nodeId: self.id,
                           existingInputsObservers: self.inputsObservers)
    }
    
    @MainActor
    static func refreshInputs(schemaInputs: [NodeConnectionType],
                              graph: GraphState,
                              nodeId: UUID,
                              existingInputsObservers: [InputNodeRowObserver]) -> [InputNodeRowObserver] {
        let splitterInputs = Self.getInputSplitters(graph: graph)
        
        let newInputs = splitterInputs.enumerated().compactMap { index, splitterInput -> InputNodeRowObserver? in
            let schemaInput = schemaInputs[safe: index]
            
            if let existingInput = existingInputsObservers[safe: index] {
                guard let schemaInput = schemaInput else {
                    // Expected schema input here
                    fatalErrorIfDebug()
                    return nil
                }

                let portSchema = NodePortInputEntity(id: .init(portId: index,
                                                               nodeId: nodeId),
                                                     portData: schemaInput)
                existingInput.update(from: portSchema)
                
                return existingInput
            }
            
            switch schemaInput {
            case .upstreamConnection(let upstreamCoordinateId):
                return InputNodeRowObserver(values: splitterInput.values,
                                            id: .init(portId: index,
                                                      nodeId: nodeId),
                                            upstreamOutputCoordinate: upstreamCoordinateId)

            default:
                let values = schemaInput?.values ?? splitterInput.allLoopedValues
                return InputNodeRowObserver(values: values,
                                            id: .init(portId: index,
                                                      nodeId: nodeId),
                                            upstreamOutputCoordinate: nil)
            }
        }
        
        return newInputs
    }
    
    @MainActor
    func refreshOutputs() -> [OutputNodeRowObserver] {
        Self.refreshOutputs(graph: self.graph,
                            nodeId: self.id,
                            existingOutputsObservers: self.outputsObservers)
    }
    
    @MainActor
    static func refreshOutputs(graph: GraphState,
                               nodeId: NodeId,
                               existingOutputsObservers: [OutputNodeRowObserver]) -> [OutputNodeRowObserver] {
        let splitterOutputs = Self.getOutputSplitters(graph: graph)
        let outputsObservers = splitterOutputs.enumerated().map { index, splitterOutput in
            if let existingOutput = existingOutputsObservers[safe: index] {
                existingOutput.updateValuesInOutput(splitterOutput.values, graph: graph)
                return existingOutput
            }
            
            return OutputNodeRowObserver(values: splitterOutput.values,
                                         id: .init(portId: index,
                                                   nodeId: nodeId))
        }
        
        return outputsObservers
    }
    
    @MainActor
    convenience init(nodeId: UUID,
                     componentEntity: ComponentEntity,
                     encodedComponent: StitchComponent,
                     parentGraphPath: [UUID],
                     componentEncoder: ComponentEncoder) async {
        let graph = await GraphState(from: encodedComponent.graph,
                                     // TODO: ComponentEntity or GraphEntity should persist their own localPosition?
                                     localPosition: ABSOLUTE_GRAPH_CENTER,
                                     saveLocation: parentGraphPath + [componentEntity.componentId],
                                     encoder: componentEncoder)
        self.init(nodeId: nodeId,
                  componentEntity: componentEntity,
                  graph: graph)
    }
}

extension StitchComponentViewModel {
    @MainActor static func createEmpty() -> Self {
        .init(nodeId: .init(),
              componentEntity: ComponentEntity(componentId: .init(),
                                               inputs: [],
                                               canvasEntity: .init(position: .zero,
                                                                   zIndex: .zero,
                                                                   parentGroupNodeId: nil)),
              graph: .init())
    }
    
    @MainActor
    func initializeDelegate(node: NodeViewModel,
                            components: [UUID: StitchMasterComponent],
                            document: StitchDocumentViewModel) {
        self.nodeDelegate = node
        
        guard let masterComponent = components.get(self.componentId) else {
            fatalErrorIfDebug()
            return
        }
        
        self.componentDelegate = masterComponent
        
        self.canvas.assignNodeReferenceAndUpdateFieldGroupsOnRowViewModels(
            node,
            activeIndex: document.activeIndex,
            unpackedPortParentFieldGroupType: nil,
            unpackedPortIndex: nil,
            graph: graph)
        
        self.graph.assignReferencesAndUpdateUICaches(document: document,
                                      documentEncoderDelegate: masterComponent.encoder)
        
        // Updates inputs and outputs
        self.inputsObservers.forEach { $0.assignNodeReferenceAndHandleValueChange(node, graph: self.graph) }
        self.outputsObservers.forEach { $0.assignNodeReferenceAndHandleValueChange(node, graph: self.graph) }
        
        // Refresh port data
        self.refreshPorts(activeIndex: document.activeIndex)
    }
    
    @MainActor func createSchema() -> ComponentEntity {
        let inputs = self.inputsObservers
            .map { $0.createSchema().portData }
        
        return .init(componentId: self.componentId,
                     inputs: inputs,
                     canvasEntity: self.canvas.createSchema())
    }
    
    @MainActor func update(from schema: ComponentEntity,
                           components: [UUID : StitchMasterComponent],
                           activeIndex: ActiveIndex) {
        self.componentId = schema.componentId
        
        guard let masterComponent = components.get(self.componentId) else {
            fatalErrorIfDebug()
            return
        }
        
        self.graph.update(from: masterComponent.lastEncodedDocument.graph)
        
        // Refresh after graph update
        self.canvas.update(from: schema.canvasEntity)
        self.refreshPorts(schemaInputs: schema.inputs,
                          activeIndex: activeIndex)
    }
    
    @MainActor func syncPorts(schemaInputs: [NodeConnectionType]? = nil,
                              activeIndex: ActiveIndex) {
        let schemaInputs = schemaInputs ?? self.createSchema().inputs
        
        self.inputsObservers = self.refreshInputs(schemaInputs: schemaInputs)
        self.outputsObservers = self.refreshOutputs()
        self.canvas.syncRowViewModels(inputRowObservers: self.inputsObservers,
                                      outputRowObservers: self.outputsObservers,
                                      activeIndex: activeIndex)
    }
    
    @MainActor
    static func getInputSplitters(graph: GraphState) -> [InputNodeRowObserver] {
        getSplitterInputRowObservers(for: nil, from: graph)
    }
    
    @MainActor
    static func getOutputSplitters(graph: GraphState) -> [OutputNodeRowObserver] {
        getSplitterOutputRowObservers(for: nil, from: graph)
    }
}

extension StitchComponentViewModel {
    @MainActor
    var id: NodeId {
        guard let node = self.nodeDelegate else {
            fatalErrorIfDebug()
            return .init()
        }
        
        return node.id
    }
    
    @MainActor func evaluate() -> EvalResult? {
        // Update splitters
        let splitterInputs = Self.getInputSplitters(graph: self.graph)
        
        assertInDebug(splitterInputs.count == self.inputsObservers.count)
        
        // Update graph's inputs before calculating full graph
        zip(splitterInputs, self.inputsObservers).forEach { splitter, input in
            splitter.updateValuesInInput(input.allLoopedValues)
        }
        
        self.graph.runGraphAndUpdateUI(from: self.graph.allNodesToCalculate)
        
        return self.evaluateOutputSplitters()
    }
    
    @MainActor
    /// Used in capacities where output splitters may have been updated, allowing us to start eval again from this graph.
    func evaluateOutputSplitters() -> EvalResult {
        let splitterOutputs = Self.getOutputSplitters(graph: self.graph)
        assertInDebug(splitterOutputs.count == self.outputsObservers.count)
        
        // Update outputs here after graph calculation
        zip(splitterOutputs, self.outputsObservers).forEach { splitter, output in
            output.updateValuesInOutput(splitter.allLoopedValues, graph: self.graph)
        }
        
        return .init(outputsValues: self.outputsObservers.map(\.allLoopedValues))
    }
    
    @MainActor func getInputRowObserver(for id: NodeIOPortType) -> InputNodeRowObserver? {
        guard let portId = id.portId,
              let input = self.inputsObservers[safe: portId] else {
            fatalErrorIfDebug()
            return nil
        }
        
        return input
    }
    
    @MainActor var inputsValuesList: PortValuesList {
        self.inputsObservers.map { $0.allLoopedValues }
    }
}

extension GraphState {
    /// Captures parent graph state in event this graph state is used for component.
    @MainActor
    var parentGraph: GraphState? {
        guard let parentComponentDelegate = self.documentEncoderDelegate as? ComponentEncoder,
              let parentGraph = parentComponentDelegate.delegate?.parentGraph else {
                  return nil
        }
        
        return parentGraph
    }
    
    @MainActor
    func evaluateComponentOutputs() {
        assertInDebug(!self.saveLocation.isEmpty)
        
        guard let parentGraph = self.parentGraph,
              // TODO: is this accurate? we're using a GraphState.id to retrieve a node in the parentGraph?
              let node = parentGraph.nodes.get(self.id.value),
              let componentNode = node.componentNode else {
            fatalErrorIfDebug()
                  return
        }
        
        let prevOutputs = node.outputs
        let evalResult = componentNode.evaluateOutputSplitters()
        
        let changedDownstreamInputs = parentGraph
            .getChangedDownstreamInputIds(evalResult: evalResult,
                                          sourceNode: node,
                                          existingOutputsValues: prevOutputs,
                                          outputCoordinates: node.outputCoordinates)
        
        let downstreamNodes = changedDownstreamInputs.map(\.nodeId).toSet
        
        // Calculate connections from component outputs
        parentGraph.runGraphAndUpdateUI(from: downstreamNodes)
    }
}
