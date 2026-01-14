// PocketBizz 5-Year Revenue Projection Data
// Realistic assumptions for Malaysian SAAS market

const projectionData = {
    // Year-by-year breakdown
    years: [
        {
            year: 2025,
            phase: 'Malaysia Launch',
            users: {
                total: 500,
                free: 350,
                starter: 100,
                professional: 40,
                enterprise: 10
            },
            revenue: {
                monthly: 15000,
                annual: 180000,
                cumulative: 180000
            },
            market: {
                primary: 'Malaysia',
                expansion: null
            },
            keyMilestones: [
                'Local market launch',
                'FPX & DuitNow integration',
                'Bahasa Malaysia support'
            ]
        },
        {
            year: 2026,
            phase: 'ASEAN Expansion',
            users: {
                total: 2500,
                free: 1750,
                starter: 500,
                professional: 200,
                enterprise: 50
            },
            revenue: {
                monthly: 75000,
                annual: 900000,
                cumulative: 1080000
            },
            market: {
                primary: 'Malaysia',
                expansion: ['Singapore', 'Indonesia']
            },
            keyMilestones: [
                'Regional expansion (SG, ID)',
                'Multi-currency support',
                'Regional payment methods'
            ]
        },
        {
            year: 2027,
            phase: 'App Store Launch',
            users: {
                total: 8000,
                free: 5600,
                starter: 1600,
                professional: 600,
                enterprise: 200
            },
            revenue: {
                monthly: 240000,
                annual: 2880000,
                cumulative: 3960000
            },
            market: {
                primary: 'Malaysia',
                expansion: ['Singapore', 'Indonesia', 'Thailand']
            },
            keyMilestones: [
                'iOS & Android apps launch',
                'International payment gateways',
                'Thailand market entry'
            ]
        },
        {
            year: 2028,
            phase: 'Global Entry',
            users: {
                total: 15000,
                free: 10500,
                starter: 3000,
                professional: 1200,
                enterprise: 300
            },
            revenue: {
                monthly: 450000,
                annual: 5400000,
                cumulative: 9360000
            },
            market: {
                primary: 'Malaysia',
                expansion: ['Singapore', 'Indonesia', 'Thailand', 'Australia', 'UK']
            },
            keyMilestones: [
                'Australia & UK market entry',
                'GDPR compliance',
                'Multi-language support'
            ]
        },
        {
            year: 2029,
            phase: 'Scale & Optimize',
            users: {
                total: 25000,
                free: 17500,
                starter: 5000,
                professional: 2000,
                enterprise: 500
            },
            revenue: {
                monthly: 750000,
                annual: 9000000,
                cumulative: 18360000
            },
            market: {
                primary: 'Malaysia',
                expansion: ['Singapore', 'Indonesia', 'Thailand', 'Australia', 'UK', 'US']
            },
            keyMilestones: [
                'US market entry',
                'AI-powered features',
                'Enterprise partnerships',
                'White-label solutions'
            ]
        }
    ],
    
    // Pricing tiers (monthly in RM)
    pricing: {
        free: 0,
        starter: 49,
        professional: 149,
        enterprise: 499
    },
    
    // Market assumptions
    assumptions: {
        conversionRate: 0.15, // 15% free to paid
        monthlyChurnRate: 0.04, // 4% monthly churn
        averageRevenuePerUser: 90, // RM 90/month ARPU
        malaysiaSMEMarket: 1200000, // 1.2M SMEs in Malaysia
        targetPenetration: 0.02 // 2% market penetration by Year 5
    },
    
    // Growth rates
    growthRates: {
        year1: 0, // Starting year
        year2: 4.0, // 400% growth (500 to 2500)
        year3: 2.2, // 220% growth (2500 to 8000)
        year4: 0.875, // 87.5% growth (8000 to 15000)
        year5: 0.667 // 66.7% growth (15000 to 25000)
    },
    
    // Revenue breakdown by tier
    getRevenueByTier: function(yearData) {
        return {
            starter: yearData.users.starter * this.pricing.starter,
            professional: yearData.users.professional * this.pricing.professional,
            enterprise: yearData.users.enterprise * this.pricing.enterprise,
            total: (yearData.users.starter * this.pricing.starter) +
                   (yearData.users.professional * this.pricing.professional) +
                   (yearData.users.enterprise * this.pricing.enterprise)
        };
    },
    
    // Calculate MRR (Monthly Recurring Revenue)
    getMRR: function(yearData) {
        const revenue = this.getRevenueByTier(yearData);
        return revenue.total;
    },
    
    // Calculate ARR (Annual Recurring Revenue)
    getARR: function(yearData) {
        return this.getMRR(yearData) * 12;
    }
};

// Export for use in other scripts
if (typeof module !== 'undefined' && module.exports) {
    module.exports = projectionData;
}
