// admin-web 프로덕션 배포 + 실제 사용 도메인 alias를 한 번에 묶는 스크립트.
//
// 문제: `vercel --prod`는 매번 팀명 기반 기본 도메인
// (admin-web-dongha1235s-projects.vercel.app)에만 자동 alias하고,
// 실제 운영 도메인(admin-web-khaki-gamma.vercel.app)에는 alias하지 않는다.
// khaki-gamma는 `vercel domains ls`에 안 잡히는 초기 auto-alias라 Vercel이
// 이후 배포마다 자동으로 따라가지 않기 때문 — 매번 수동으로 alias set을
// 잊으면 실제 사이트는 예전 버전에 머무른다. 이 스크립트가 그 두 단계를
// 항상 함께 실행해서 그 문제를 원천 차단한다.

import { execSync } from "node:child_process";

const PROD_DOMAIN = "admin-web-khaki-gamma.vercel.app";

function run(cmd) {
  console.log(`\n$ ${cmd}`);
  return execSync(cmd, { stdio: ["inherit", "pipe", "inherit"], encoding: "utf8" });
}

const deployOutput = run("vercel --prod --yes");
console.log(deployOutput);

const match = deployOutput.match(/https:\/\/[a-zA-Z0-9-]+\.vercel\.app/g);
if (!match || match.length === 0) {
  console.error(
    "배포 URL을 찾지 못했어요. 위 출력에서 Production URL을 확인해 직접 실행하세요:\n" +
      `  vercel alias set <배포URL> ${PROD_DOMAIN}`,
  );
  process.exit(1);
}
// 마지막에 나오는 vercel.app URL이 이번 배포의 production URL
const deployedUrl = match[match.length - 1];

run(`vercel alias set ${deployedUrl} ${PROD_DOMAIN}`);

console.log(`\n✅ ${PROD_DOMAIN} 이(가) 이번 배포(${deployedUrl})를 가리키도록 갱신했어요.`);
