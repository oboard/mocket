pub enum PromiseStatus {
  Pending
  Fulfilled
  Rejected
}

pub struct Promise[T] {
  mut status : PromiseStatus
  mut value : T?
  then_callbacks : Array[(T) -> Unit]
  capture_callbacks : Array[(T) -> Unit]
}

pub fn Promise::new[T](task : ((T) -> Unit, (T) -> Unit) -> Unit) -> Promise[T] {
  let promise = {
    status: Pending,
    value: None,
    then_callbacks: [],
    capture_callbacks: [],
  }
  task(
    fn(value) {
      promise.status = Fulfilled
      promise.value = Some(value)
    },
    fn(error) {
      promise.status = Rejected
      promise.value = Some(error)
    },
  )
  promise
}

pub fn Promise::then[T](
  self : Promise[T],
  callback : (T) -> Unit
) -> Promise[T] {
  match (self.status, self.value) {
    (Fulfilled, Some(value)) => callback(value)
    (Pending, _) => self.then_callbacks.push(callback)
    _ => ()
  }
  self
}

pub fn Promise::capture[T](
  self : Promise[T],
  callback : (T) -> Unit
) -> Promise[T] {
  match (self.status, self.value) {
    (Fulfilled, Some(value)) => callback(value)
    (Rejected, Some(error)) => callback(error)
    (Pending, _) => self.then_callbacks.push(callback)
    _ => ()
  }
  self
}

pub fn Promise::resolve[T](self : Promise[T], value : T) -> Unit {
  self.value = Some(value)
  self.then_callbacks.each(fn(callback) { callback(value) })
}

pub fn Promise::reject[T](self : Promise[T], error : T) -> Unit {
  self.value = None
  self.capture_callbacks.each(fn(callback) { callback(error) })
}
