Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " STARTING EVENTOLOGY FULL DATABASE & SCHEMA VERIFICATION " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

$scripts = @(
  "verifyLocations.ts",
  "verifyCategories.ts",
  "verifyEventTypes.ts",
  "verifyVenueTypes.ts",
  "verifyUsers.ts",
  "verifyServices.ts",
  "verifyVendors.ts",
  "verifyVenues.ts",
  "verifyPackages.ts",
  "verifyEvents.ts",
  "verifyEnquiries.ts",
  "verifyBookings.ts",
  "verifyAllocations.ts",
  "verifyPayments.ts",
  "verifyReviews.ts",
  "verifyNotifications.ts",
  "verifyAiPlans.ts",
  "verifyAiRecommendations.ts",
  "verifyAgentTasks.ts",
  "verifyAgentLogs.ts",
  "verifyAuditLogs.ts",
  "verifySettings.ts"
)

foreach ($script in $scripts) {
  Write-Host "--> Running $script ..." -ForegroundColor Yellow
  npx ts-node "src/scripts/$script"
  if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED executing $script" -ForegroundColor Red
  }
  Write-Host ""
}

Write-Host "==================================================" -ForegroundColor Green
Write-Host " VERIFICATION RUN COMPLETE " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
