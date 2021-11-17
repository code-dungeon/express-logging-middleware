const express = require('express');
const { ctx } = require('@code-dungeon/context-continuation');
const { Logger } = require('@code-dungeon/toothpick');
const { LoggingMiddleware } = require('./dist/LoggingMiddleware');

const app = express();
const port = 8080;
const cidFormat = Logger.Format.context(() => {
  return ctx.cid;
}, 'cid');

Logger.Config.formats.push(cidFormat);

const contextFormat = Logger.Format.context(() => {
  const { statusCode, duration, path } = ctx.http;
  let response = ctx.http.responseBody;
  // console.log('http:', ctx.http);

  return { duration, path, response, statusCode };
});

// const entryLogger = Logger.create({ format: [entryFormat, ...Logger.Config.formats] });
// const exitLogger = Logger.create({ format: [exitFormat, ...Logger.Config.formats] });

const logger = Logger.create({ formats: [contextFormat, ...Logger.Config.formats] });
app.use(LoggingMiddleware(logger));
// app.use(LoggingMiddleware(entryLogger, exitLogger));
app.get('/test', (request, response) => {
  if (request.query.arg) {
    response.status(400).json({ status: 'oops!' });
  } else {
    response.json({ status: 'ok' });
  }

});
app.listen(port);
