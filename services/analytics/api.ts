import crypto from "node:crypto";

import { api } from "encore.dev/api";
import { CronJob } from "encore.dev/cron";

import {
  AnalyticsOverviewResponse,
  ReportGenerationResponse,
} from "./types";

export const analyticsOverview = api(
  {
    method: "GET",
    path: "/analytics/overview",
  },
  async (): Promise<AnalyticsOverviewResponse> => {
    // TODO(p2): aggregate Supabase metrics for dashboard cards
    return {
      summary: {
        totalSales: 0,
        totalExpenses: 0,
        grossProfit: 0,
        generatedAt: new Date().toISOString(),
      },
    };
  }
);

export const generateMonthlyReport = api(
  {
    method: "POST",
    path: "/analytics/generate-report",
  },
  async (): Promise<ReportGenerationResponse> => {
    // TODO(p2): collect KPIs and upload compiled PDF/CSV artifact
    return {
      reportId: crypto.randomUUID(),
      status: "pending",
    };
  }
);

const _monthlyReportCron = new CronJob("monthly-report", {
  title: "Monthly KPI report generation",
  schedule: "0 0 1 * *",
  endpoint: generateMonthlyReport,
});

