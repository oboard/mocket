import http from "node:http";
import fs from "node:fs";

export default class Mocket {
  init(heaven) {
    const objPool = [];
    let server = undefined;

    const pushObj = (res) => {
      // 查找responses中的空位，如果没有空位，则添加到末尾
      const index = objPool.findIndex((r) => r === undefined);
      if (index === -1) {
        objPool.push(res);
        return objPool.length - 1;
      }
      objPool[index] = res;
      return index;
    };

    heaven.listenEvent("fetch", (url) => {
      return new Promise((resolve, reject) => {
        const req = http.get(url, (res) => {
          let data = "";
          res.on("data", (chunk) => {
            data += chunk;
          });
          res.on("end", () => {
            resolve({
              status: res.statusCode,
              headers: res.headers,
              body: data,
            });
          });
        });
        req.on("error", (err) => {
          reject(err);
        });
      });
    });

    heaven.listenEvent("fs.readFile", (path) => {
      let uint8array = fs.readFileSync(path);
      return Array.from(new Uint8Array(uint8array));
    });

    heaven.listenEvent("fs.readDir", (path) => {
      return fs.readdirSync(path);
    });

    heaven.listenEvent("fs.writeFile", (path, data) => {
      fs.writeFileSync(path, Buffer.from(data));
    });

    heaven.listenEvent("http.createServer", () => {
      server = http.createServer((req, res) => {
        const callRequest = (data) => {
          heaven.sendEvent("http.request", [
            {
              url: req.url,
              method: req.method,
              headers: req.headers,
              body: data,
            },
            { id: pushObj(res) },
          ]);
        };

        // 检测请求方法是否为POST
        if (req.method === "POST") {
          let body = "";
          // 监听数据事件，将请求体数据累加到body变量
          req.on("data", (chunk) => {
            body += chunk.toString(); // 将Buffer转换为字符串
          });

          // 监听结束事件，完成body的接收
          req.on("end", () => {
            callRequest(body);
          });
        } else {
          callRequest();
        }
      });
    });

    heaven.listenEvent("http.listen", (port) => {
      if (!server) {
        throw new Error("Server not created");
      }
      server.listen(port, () => {
        console.info(`Server running on port ${port}`);
      });
    });

    heaven.listenEvent("http.writeHead", (id, statusCode, headers) => {
      const response = objPool[id];
      if (!response) {
        throw new Error("Response not created");
      }
      response.writeHead(statusCode, headers);
    });

    heaven.listenEvent("http.end", (id, data) => {
      const response = objPool[id];
      if (!response) {
        throw new Error(`Response ${id} not created`);
      }
      // 如果data是对象，则转化为JSON字符串

      if (typeof data === "object") {
        if (data.type === "file") {
          const file = objPool[data.id];
          if (!file) {
            throw new Error(`File ${data.id} not found`);
          }
          response.end(file);
          return;
        }
        response.end(JSON.stringify(data));
      } else {
        response.end(data);
      }
      objPool[id] = undefined;
    });
  }
}