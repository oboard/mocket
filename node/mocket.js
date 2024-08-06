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
      fetch(url)
        .then((res) => res.text())
        .then((text) => {
          heaven.sendEvent("fetch.text", [url, text]);
        });

      return undefined;
    });

    heaven.listenEvent("fs.readFile", (path) => {
      let uint8array = fs.readFileSync(path);
      return Array.from(new Uint8Array(uint8array));
    });

    heaven.listenEvent("fs.readDir", (path) => {
      // return fs.readdirSync(path);
      // 遍历目录，返回文件名数组
      function readDir(path) {
        const files = fs.readdirSync(path);
        const result = [];
        files.forEach((file) => {
          const stats = fs.statSync(path + "/" + file);
          if (stats.isFile()) {
            result.push(file);
          } else if (stats.isDirectory()) {
            result.push({
              name: file,
              type: "directory",
              children: readDir(path + "/" + file),
            });
          }
        });
        return result;
      }
      return readDir(path);
    });

    heaven.listenEvent("fs.stat", (path) => {
      return fs.statSync(path);
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
        switch (data.type) {
          case "file":
            const file = fs.readFileSync(data.path);
            response.end(file);
            break;
          case "buffer":
            const buffer = Buffer.from(data.data);
            response.end(file);
            break;
          default:
            response.end(JSON.stringify(data));
        }
      } else {
        response.end(data);
      }
      objPool[id] = undefined;
    });
  }
}
