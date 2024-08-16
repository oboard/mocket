// biome-ignore lint/style/useNodejsImportProtocol: <explanation>
import fs from "fs";

export default class Heaven {
  _mbt_callbacks = null;
  _mbt_listeners = {};
  listenEvent(type, callback) {
    this._mbt_listeners[type] = callback;
  }

  bindObject(prefix, obj) {
    if (obj === null || typeof obj === "undefined" || typeof obj !== "object") {
      return;
    }
    const prototype = Object.getPrototypeOf(obj);
    if (prototype === null) {
      return;
    }
    const properties = Object.getOwnPropertyNames(prototype);

    this.listenEvent(`${prefix}.addEventListener`, (type, listener) => {
      obj.addEventListener(type, (...args) => {
        function getCompleteObject(obj) {
          const result = {};
          const keys = [...Object.getOwnPropertyNames(obj)];
          for (const key of keys) {
            result[key] = obj[key];
          }
          return result;
        }
        sendEvent(listener, args.map(getCompleteObject));
      });
    });
    for (const methodName of properties) {
      const method = obj[methodName];

      if (typeof method === "function") {
        this.listenEvent(`${prefix}.${methodName}`, (...args) => {
          method.apply(obj, args);
        });
      } else if (typeof method === "object") {
        this.bindObject(`${prefix}.${methodName}`, method);
      } else {
        this.listenEvent(`${prefix}.${methodName}`, () => method);
        this.listenEvent(`${prefix}.${methodName}.set`, (value) => {
          obj[methodName] = value;
        });
      }
    }
  }

  sendEvent(eventType, data) {
    const json = JSON.stringify([eventType, data]);
    const uint8array = new TextEncoder("utf-16")
      .encode(json)
      .reduce((acc, byte) => {
        acc.push(byte, 0);
        return acc;
      }, []);
    for (let i = 0; i < uint8array.length; i++) {
      this._mbt_callbacks.h_rd(uint8array[i]);
    }
    this._mbt_callbacks.h_re();
  }

  init() {
    const [log, flush] = (() => {
      let buffer = [];
      return [
        (ch) => {
          if (ch === "\n".charCodeAt(0)) flush();
          else if (ch !== "\r".charCodeAt(0)) buffer.push(ch);
        },
        () => {
          if (buffer.length > 0) {
            console.log(
              new TextDecoder("utf-16")
                .decode(new Uint16Array(buffer))
                .replace(/\0/g, "")
            );
            buffer = [];
          }
        },
      ];
    })();

    const [h_sd, h_se] = (() => {
      let buffer = [];
      return [
        (ch) => buffer.push(ch),
        () => {
          if (buffer.length > 0) {
            const str = new TextDecoder("utf-16")
              .decode(new Uint16Array(buffer))
              .replace(/\0/g, "");
            handleReceive(JSON.parse(str));
            buffer = [];
          }
        },
      ];
    })();

    const importObject = {
      __h: { h_sd, h_se },
      spectest: { print_char: log },
    };

    const handleReceive = (res) => {
      const [type, data, id] = res;
      switch (type) {
        case "log":
          console.log(data);
          break;
        case "error":
          console.error(data);
          break;
        default:
          if (type in this._mbt_listeners) {
            const f = this._mbt_listeners[type];
            const result = Array.isArray(data) ? f(...data) : f(data);
            if (id !== undefined && result !== undefined) {
              this.sendEvent(id, result);
            }
          }
      }
    };
    const bytes = fs.readFileSync("./assets/app.wasm");
    WebAssembly.instantiate(bytes, importObject).then((obj) => {
      this._mbt_callbacks = obj.instance.exports;
      this._mbt_callbacks._start();
    });
  }
}
