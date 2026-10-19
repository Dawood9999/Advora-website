const { test, expect } = require('@playwright/test');

test('demo registration, package activation, daily reward limit, and session persistence', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle(/AdVora/i);
  await expect(page.getByText(/No real money is deposited or paid/i)).toBeVisible();

  const unique = 'qa_' + Date.now().toString().slice(-8);
  await page.locator('#regName').fill(unique);
  await page.locator('#regPass').fill('DemoPass123!');
  await page.getByRole('button', { name: 'Register Demo Account' }).click();

  await expect(page.locator('#dashboard')).toBeVisible();
  await expect(page.locator('#welcome')).toContainText(unique);
  await expect(page.locator('#videoCount')).toHaveText('0/0');

  await page.getByRole('button', { name: 'Activate Demo' }).first().click();
  await expect(page.locator('#activePackage')).toHaveText('$10.00');
  await expect(page.locator('#videoCount')).toHaveText('0/3');

  const claim = page.getByRole('button', { name: /Claim Demo Video Reward/ });
  for (let n = 1; n <= 3; n++) {
    await claim.click();
    await expect(page.locator('#videoCount')).toHaveText(`${n}/3`);
  }
  await expect(page.locator('#packageBal')).toHaveText('$0.51');
  await expect(claim).toBeDisabled();
  // The button is disabled at the daily limit; verify no extra reward is possible.
  await expect(claim).toBeDisabled();
  await expect(page.locator('#packageBal')).toHaveText('$0.51');

  await page.reload();
  await expect(page.locator('#dashboard')).toBeVisible();
  await expect(page.locator('#welcome')).toContainText(unique);
  await expect(page.locator('#packageBal')).toHaveText('$0.51');
  await expect(page.locator('#videoCount')).toHaveText('3/3');
});

test('demo package limits and reward disclaimer are explicit in source', async ({ page }) => {
  await page.goto('/');
  const html = await page.locator('body').innerText();
  expect(html).toContain('server and database are required for real users to share data');
  const source = await page.content();
  expect(source).toContain('This button records a demo reward only');
  expect(source).toContain('if(packageValue>=100) return 15');
  expect(source).toContain('if(packageValue>=50) return 10');
  expect(source).toContain('if(packageValue>=30) return 6');
  expect(source).toContain('if(packageValue>=10) return 3');
});
