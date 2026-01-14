// Chart.js configurations and rendering
// Uses projection-data.js for data

// Format currency in RM
function formatCurrency(value) {
    return new Intl.NumberFormat('ms-MY', {
        style: 'currency',
        currency: 'MYR',
        minimumFractionDigits: 0,
        maximumFractionDigits: 0
    }).format(value);
}

// Format number with K/M suffix
function formatNumber(value) {
    if (value >= 1000000) {
        return (value / 1000000).toFixed(1) + 'M';
    } else if (value >= 1000) {
        return (value / 1000).toFixed(1) + 'K';
    }
    return value.toString();
}

// Revenue Growth Chart
const revenueCtx = document.getElementById('revenueChart');
if (revenueCtx) {
    const revenueData = projectionData.years.map(year => year.revenue.annual);
    const revenueLabels = projectionData.years.map(year => year.year.toString());
    
    new Chart(revenueCtx, {
        type: 'line',
        data: {
            labels: revenueLabels,
            datasets: [{
                label: 'Annual Revenue (RM)',
                data: revenueData,
                borderColor: 'rgb(99, 102, 241)',
                backgroundColor: 'rgba(99, 102, 241, 0.1)',
                borderWidth: 3,
                fill: true,
                tension: 0.4,
                pointRadius: 6,
                pointHoverRadius: 8,
                pointBackgroundColor: 'rgb(99, 102, 241)',
                pointBorderColor: '#fff',
                pointBorderWidth: 2
            }, {
                label: 'Cumulative Revenue (RM)',
                data: projectionData.years.map(year => year.revenue.cumulative),
                borderColor: 'rgb(16, 185, 129)',
                backgroundColor: 'rgba(16, 185, 129, 0.1)',
                borderWidth: 3,
                fill: true,
                tension: 0.4,
                borderDash: [5, 5],
                pointRadius: 6,
                pointHoverRadius: 8
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: {
                    display: true,
                    position: 'top',
                    labels: {
                        font: {
                            size: 14,
                            weight: '600'
                        },
                        padding: 20
                    }
                },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            return context.dataset.label + ': ' + formatCurrency(context.parsed.y);
                        }
                    }
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    ticks: {
                        callback: function(value) {
                            return formatCurrency(value);
                        },
                        font: {
                            size: 12
                        }
                    },
                    grid: {
                        color: 'rgba(0, 0, 0, 0.05)'
                    }
                },
                x: {
                    ticks: {
                        font: {
                            size: 12
                        }
                    },
                    grid: {
                        display: false
                    }
                }
            }
        }
    });
}

// User Growth Chart
const userCtx = document.getElementById('userChart');
if (userCtx) {
    const totalUsers = projectionData.years.map(year => year.users.total);
    const paidUsers = projectionData.years.map(year => 
        year.users.starter + year.users.professional + year.users.enterprise
    );
    const malaysiaUsers = projectionData.years.map((year, index) => {
        // Estimate: 100% Year 1, 80% Year 2, 60% Year 3, 50% Year 4, 40% Year 5
        const malaysiaPercentage = [1.0, 0.8, 0.6, 0.5, 0.4][index];
        return Math.round(year.users.total * malaysiaPercentage);
    });
    const internationalUsers = projectionData.years.map((year, index) => {
        const malaysiaPercentage = [1.0, 0.8, 0.6, 0.5, 0.4][index];
        return Math.round(year.users.total * (1 - malaysiaPercentage));
    });
    
    new Chart(userCtx, {
        type: 'bar',
        data: {
            labels: projectionData.years.map(year => year.year.toString()),
            datasets: [
                {
                    label: 'Total Users',
                    data: totalUsers,
                    backgroundColor: 'rgba(99, 102, 241, 0.8)',
                    borderColor: 'rgb(99, 102, 241)',
                    borderWidth: 2
                },
                {
                    label: 'Paid Users',
                    data: paidUsers,
                    backgroundColor: 'rgba(16, 185, 129, 0.8)',
                    borderColor: 'rgb(16, 185, 129)',
                    borderWidth: 2
                },
                {
                    label: 'Malaysia Users',
                    data: malaysiaUsers,
                    backgroundColor: 'rgba(251, 191, 36, 0.8)',
                    borderColor: 'rgb(251, 191, 36)',
                    borderWidth: 2
                },
                {
                    label: 'International Users',
                    data: internationalUsers,
                    backgroundColor: 'rgba(239, 68, 68, 0.8)',
                    borderColor: 'rgb(239, 68, 68)',
                    borderWidth: 2
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: {
                    display: true,
                    position: 'top',
                    labels: {
                        font: {
                            size: 14,
                            weight: '600'
                        },
                        padding: 20
                    }
                },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            return context.dataset.label + ': ' + formatNumber(context.parsed.y) + ' users';
                        }
                    }
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    ticks: {
                        callback: function(value) {
                            return formatNumber(value);
                        },
                        font: {
                            size: 12
                        }
                    },
                    grid: {
                        color: 'rgba(0, 0, 0, 0.05)'
                    }
                },
                x: {
                    ticks: {
                        font: {
                            size: 12
                        }
                    },
                    grid: {
                        display: false
                    }
                }
            }
        }
    });
}

// Financial Metrics Chart
const metricsCtx = document.getElementById('metricsChart');
if (metricsCtx) {
    const mrrData = projectionData.years.map(year => projectionData.getMRR(year));
    const arrData = projectionData.years.map(year => projectionData.getARR(year));
    const arpuData = projectionData.years.map(year => {
        const paidUsers = year.users.starter + year.users.professional + year.users.enterprise;
        return paidUsers > 0 ? projectionData.getMRR(year) / paidUsers : 0;
    });
    
    new Chart(metricsCtx, {
        type: 'bar',
        data: {
            labels: projectionData.years.map(year => year.year.toString()),
            datasets: [
                {
                    label: 'MRR (Monthly Recurring Revenue)',
                    data: mrrData,
                    backgroundColor: 'rgba(99, 102, 241, 0.8)',
                    borderColor: 'rgb(99, 102, 241)',
                    borderWidth: 2,
                    yAxisID: 'y'
                },
                {
                    label: 'ARR (Annual Recurring Revenue)',
                    data: arrData,
                    backgroundColor: 'rgba(16, 185, 129, 0.8)',
                    borderColor: 'rgb(16, 185, 129)',
                    borderWidth: 2,
                    yAxisID: 'y'
                },
                {
                    label: 'ARPU (Average Revenue Per User)',
                    data: arpuData,
                    type: 'line',
                    borderColor: 'rgb(251, 191, 36)',
                    backgroundColor: 'rgba(251, 191, 36, 0.1)',
                    borderWidth: 3,
                    fill: false,
                    pointRadius: 6,
                    pointHoverRadius: 8,
                    yAxisID: 'y1'
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: {
                    display: true,
                    position: 'top',
                    labels: {
                        font: {
                            size: 14,
                            weight: '600'
                        },
                        padding: 20
                    }
                },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            if (context.dataset.label.includes('ARPU')) {
                                return context.dataset.label + ': RM ' + context.parsed.y.toFixed(2);
                            }
                            return context.dataset.label + ': ' + formatCurrency(context.parsed.y);
                        }
                    }
                }
            },
            scales: {
                y: {
                    type: 'linear',
                    display: true,
                    position: 'left',
                    beginAtZero: true,
                    ticks: {
                        callback: function(value) {
                            return formatCurrency(value);
                        },
                        font: {
                            size: 12
                        }
                    },
                    grid: {
                        color: 'rgba(0, 0, 0, 0.05)'
                    }
                },
                y1: {
                    type: 'linear',
                    display: true,
                    position: 'right',
                    beginAtZero: true,
                    ticks: {
                        callback: function(value) {
                            return 'RM ' + value.toFixed(0);
                        },
                        font: {
                            size: 12
                        }
                    },
                    grid: {
                        drawOnChartArea: false
                    }
                },
                x: {
                    ticks: {
                        font: {
                            size: 12
                        }
                    },
                    grid: {
                        display: false
                    }
                }
            }
        }
    });
}

// Year-by-Year Breakdown
const yearBreakdown = document.getElementById('yearBreakdown');
if (yearBreakdown) {
    projectionData.years.forEach((year, index) => {
        const revenueByTier = projectionData.getRevenueByTier(year);
        const paidUsers = year.users.starter + year.users.professional + year.users.enterprise;
        const arpu = paidUsers > 0 ? projectionData.getMRR(year) / paidUsers : 0;
        
        const yearCard = document.createElement('div');
        yearCard.className = 'border-2 border-gray-200 rounded-lg p-6 card-hover';
        yearCard.innerHTML = `
            <div class="flex items-center justify-between mb-4">
                <h3 class="text-2xl font-bold text-gray-800">${year.year} - ${year.phase}</h3>
                <span class="bg-gradient-to-r from-purple-500 to-pink-500 text-white px-4 py-2 rounded-full text-sm font-semibold">
                    Year ${index + 1}
                </span>
            </div>
            
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                <div class="bg-blue-50 p-4 rounded-lg">
                    <div class="text-sm text-gray-600 mb-1">Total Users</div>
                    <div class="text-2xl font-bold text-blue-600">${formatNumber(year.users.total)}</div>
                    <div class="text-xs text-gray-500 mt-1">Paid: ${formatNumber(paidUsers)}</div>
                </div>
                <div class="bg-green-50 p-4 rounded-lg">
                    <div class="text-sm text-gray-600 mb-1">Annual Revenue</div>
                    <div class="text-2xl font-bold text-green-600">${formatCurrency(year.revenue.annual)}</div>
                    <div class="text-xs text-gray-500 mt-1">MRR: ${formatCurrency(projectionData.getMRR(year))}</div>
                </div>
                <div class="bg-purple-50 p-4 rounded-lg">
                    <div class="text-sm text-gray-600 mb-1">ARPU</div>
                    <div class="text-2xl font-bold text-purple-600">RM ${arpu.toFixed(2)}</div>
                    <div class="text-xs text-gray-500 mt-1">Per paid user/month</div>
                </div>
            </div>
            
            <div class="mb-4">
                <h4 class="text-lg font-semibold text-gray-700 mb-2">User Breakdown</h4>
                <div class="grid grid-cols-2 md:grid-cols-4 gap-2 text-sm">
                    <div class="text-center p-2 bg-gray-50 rounded">
                        <div class="font-semibold text-gray-800">FREE</div>
                        <div class="text-gray-600">${formatNumber(year.users.free)}</div>
                    </div>
                    <div class="text-center p-2 bg-blue-50 rounded">
                        <div class="font-semibold text-blue-800">STARTER</div>
                        <div class="text-blue-600">${formatNumber(year.users.starter)}</div>
                        <div class="text-xs text-gray-500">RM ${formatCurrency(revenueByTier.starter)}/mo</div>
                    </div>
                    <div class="text-center p-2 bg-purple-50 rounded">
                        <div class="font-semibold text-purple-800">PRO</div>
                        <div class="text-purple-600">${formatNumber(year.users.professional)}</div>
                        <div class="text-xs text-gray-500">RM ${formatCurrency(revenueByTier.professional)}/mo</div>
                    </div>
                    <div class="text-center p-2 bg-yellow-50 rounded">
                        <div class="font-semibold text-yellow-800">ENTERPRISE</div>
                        <div class="text-yellow-600">${formatNumber(year.users.enterprise)}</div>
                        <div class="text-xs text-gray-500">RM ${formatCurrency(revenueByTier.enterprise)}/mo</div>
                    </div>
                </div>
            </div>
            
            <div class="mb-4">
                <h4 class="text-lg font-semibold text-gray-700 mb-2">Market Expansion</h4>
                <div class="flex flex-wrap gap-2">
                    <span class="bg-green-100 text-green-800 px-3 py-1 rounded-full text-sm font-semibold">
                        ${year.market.primary}
                    </span>
                    ${year.market.expansion ? year.market.expansion.map(country => 
                        `<span class="bg-blue-100 text-blue-800 px-3 py-1 rounded-full text-sm font-semibold">${country}</span>`
                    ).join('') : ''}
                </div>
            </div>
            
            <div>
                <h4 class="text-lg font-semibold text-gray-700 mb-2">Key Milestones</h4>
                <ul class="list-disc list-inside space-y-1 text-gray-600">
                    ${year.keyMilestones.map(milestone => `<li>${milestone}</li>`).join('')}
                </ul>
            </div>
        `;
        
        yearBreakdown.appendChild(yearCard);
    });
}

// Add smooth scroll animation on load
window.addEventListener('load', () => {
    const elements = document.querySelectorAll('.animate-fade-in-up');
    elements.forEach((el, index) => {
        setTimeout(() => {
            el.style.opacity = '0';
            el.style.transform = 'translateY(20px)';
            setTimeout(() => {
                el.style.transition = 'opacity 0.6s ease-out, transform 0.6s ease-out';
                el.style.opacity = '1';
                el.style.transform = 'translateY(0)';
            }, 50);
        }, index * 100);
    });
});
