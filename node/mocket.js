import http from "node:http";
import fs from "node:fs";

export default class Mocket {
  init(heaven) {
    const responses = [];
    let server = undefined;

    const createResponse = (res) => {
      // 查找responses中的空位，如果没有空位，则添加到末尾
      const index = responses.findIndex((r) => r === undefined);
      if (index === -1) {
        responses.push(res);
        return responses.length - 1;
      }
      responses[index] = res;
      return index;
    };

    heaven.defineEvent("http.createServer", () => {
      console.log("Creating server");
      server = http.createServer((req, res) => {
        const callRequest = (data) => {
          heaven.callFunction("http.request", [
            {
              url: req.url,
              method: req.method,
              headers: req.headers,
              body: data,
            },
            { id: createResponse(res) },
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

    heaven.defineEvent("http.listen", (port) => {
      if (!server) {
        throw new Error("Server not created");
      }
      server.listen(port, () => {
        console.info(`Server running on port ${port}`);
      });
    });

    heaven.defineEvent("http.writeHead", (id, statusCode, headers) => {
      const response = responses[id];
      if (!response) {
        throw new Error("Response not created");
      }
      response.writeHead(statusCode, headers);
    });

    heaven.defineEvent("http.end", (id, data) => {
      const response = responses[id];
      if (!response) {
        throw new Error(`Response ${id} not created`);
      }
      // 如果data是对象，则转化为JSON字符串

      if (typeof data === "object") {
        if (data.type === "file") {
          const filePath = data.path;
          const file = fs.readFileSync(filePath);
          const contentType = data.contentType || "application/octet-stream";
          response.writeHead(200, {
            "Content-Type": contentType,
          });
          response.end(file);
          return;
        }
        response.end(JSON.stringify(data));
      } else {
        response.end(data);
      }
      responses[id] = undefined;
    });
  }
}
