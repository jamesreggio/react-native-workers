import {NativeModules, NativeEventEmitter} from 'react-native';

const NativeModule = NativeModules.WorkersInstanceManager;
const NativeEvents = new NativeEventEmitter(NativeModule);

const self = {
  start() {
    // Intentional no-op.
    // As a worker instance, we eagerly connect to our parent below.
  },

  postMessage(message = null) {
    try {
      message = JSON.stringify(message);
    } catch (error) {
      console.warn('Unable to stringify message', message, error);
    }

    NativeModule.postMessage(message);
  },
};

NativeEvents.addListener('message', ({message}) => {
  if (!self.onmessage) {
    return;
  }

  try {
    message = JSON.parse(message);
  } catch (error) {
    console.warn('Unable to parse message', message, error);
  }

  self.onmessage(message);
});

// Signal that the worker is ready to receive messages.
// This happens in `setImmediate` to guarantee a chance to set
// `self.onmessage` before the delivery of any queued messages.
setImmediate(NativeModule.workerStarted);

export default self;
