// 상태 코드를 담은 에러. 전역 에러 핸들러가 status와 message로 응답한다.
function httpError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}

module.exports = httpError;
