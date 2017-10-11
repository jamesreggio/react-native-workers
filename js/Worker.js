import {NativeModules, NativeEventEmitter} from 'react-native';

const NativeModule = NativeModules.WorkersManager;
const NativeEvents = new NativeEventEmitter(NativeModule);

let nextKey = 0;

export default class Worker {
  key = null;
  subscription = null;
  terminated = false;
  started = null;

  constructor(bundleRoot, bundleResource, bundlerPort = 0) {
    this.key = nextKey++;

    this.subscription = NativeEvents.addListener(
      'message',
      ({key, message}) => {
        if (!this.onmessage || this.key !== key) {
          return;
        }

        try {
          message = JSON.parse(message);
          this.onmessage(message);
        } catch (error) {
          console.warn('Unable to parse message', message, error);
        }
      },
    );

    this.started = NativeModule.startWorker(
      this.key, bundleRoot, bundleResource, parseInt(bundlerPort, 10)
    );
  }

  async postMessage(message = null) {
    if (this.terminated) {
      return;
    }

    try {
      await this.started;
      message = JSON.stringify(message);
      NativeModule.postMessage(this.key, message);
    } catch (error) {
      console.warn('Unable to stringify message', message, error);
    }
  }

  async terminate() {
    if (this.terminated) {
      return;
    }

    await this.started;
    NativeEvents.removeListener(this.subscription);
    NativeModule.stopWorker(this.key);
  }
}