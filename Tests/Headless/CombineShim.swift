// Linux harness only: no Apple UI/Combine runtime is available here.
// The controller's actual UCI transport, queueing, cancellation and parsing run unchanged.
public protocol ObservableObject: AnyObject {}
@propertyWrapper public struct Published<Value> {
    public var wrappedValue: Value
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
