'use client'

import { format } from 'date-fns'
import Link from 'next/link'
import { StatCard } from '@/components/shared/StatCard'
import { Badge } from '@/components/ui/badge'

interface FollowupLead {
  id: string
  full_name: string
  phone: string
  assigned_to_name: string
}

interface TopTelecaller {
  id: string
  full_name: string
  conversions: number
  calls_made: number
  conversion_rate: string
}

interface IncentiveRow {
  month: number
  year: number
  incentive: number
  status: string
  net: number
}

interface DepartmentStat {
  id: string
  name: string
  total_students: number
  collected_fee: number
  pending_fee: number
}

interface DashboardClientProps {
  totalLeads: number
  newToday: number
  convertedThisMonth: number
  conversionRate: string
  totalFeeCollected: number
  outstandingFees: number
  activeStudents: number
  pendingDocs: number
  followupsToday: FollowupLead[]
  topTelecallers: TopTelecaller[]
  incentiveHistory?: IncentiveRow[]
  isLead?: boolean
  docReceivedCount?: number
  expectedEnrollmentCount?: number
  departmentStats?: DepartmentStat[]
}

const MONTH_NAMES = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

const fmt = (n: number) =>
  new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(n)

export default function DashboardClient({
  totalLeads,
  newToday,
  convertedThisMonth,
  conversionRate,
  totalFeeCollected,
  outstandingFees,
  activeStudents,
  pendingDocs,
  followupsToday,
  topTelecallers,
  incentiveHistory = [],
  isLead = false,
  docReceivedCount = 0,
  expectedEnrollmentCount = 0,
  departmentStats = [],
}: DashboardClientProps) {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Dashboard</h1>
        <p className="text-sm text-muted-foreground">{format(new Date(), 'EEEE, dd MMMM yyyy')}</p>
      </div>

      {/* Stat cards — row 1 */}
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <StatCard label="Total Leads" value={totalLeads} />
        <StatCard label="New Today" value={newToday} color="blue" />
        <StatCard label="Converted This Month" value={convertedThisMonth} color="green" />
        <StatCard label="Conversion Rate" value={conversionRate} color="green" />
      </div>

      {/* Stat cards — row 2 (fee stats hidden for telecallers) */}
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        {!isLead && <StatCard label="Total Fee Collected" value={fmt(totalFeeCollected)} color="green" />}
        {!isLead && <StatCard label="Outstanding Fees" value={fmt(outstandingFees)} color="amber" />}
        <StatCard label="Active Students" value={activeStudents} color="blue" />
        <StatCard label="Pending Documents" value={pendingDocs} color={pendingDocs > 0 ? 'amber' : 'default'} />
      </div>

      {/* Telecaller extra stats */}
      {isLead && (
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
          <StatCard label="Document Received" value={docReceivedCount} color="blue" />
          <StatCard label="Expected Enrollment" value={expectedEnrollmentCount} color="green" />
        </div>
      )}

      {/* 2-column grid */}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">

        {/* Followups Due Today */}
        <div className="rounded-lg border p-4 space-y-3">
          <h2 className="font-semibold text-sm">
            Followups Due Today
            {followupsToday.length > 0 && (
              <span className="ml-2 rounded-full bg-amber-100 px-1.5 py-0.5 text-xs text-amber-800">
                {followupsToday.length}
              </span>
            )}
          </h2>
          {followupsToday.length === 0 ? (
            <p className="text-xs text-muted-foreground">No followups due today</p>
          ) : (
            <table className="w-full text-xs">
              <thead>
                <tr className="text-muted-foreground">
                  <th className="text-left pb-1">Name</th>
                  <th className="text-left pb-1">Phone</th>
                  <th className="text-left pb-1">Assigned To</th>
                </tr>
              </thead>
              <tbody>
                {followupsToday.map((l) => (
                  <tr key={l.id} className="border-t">
                    <td className="py-1 font-medium">{l.full_name}</td>
                    <td className="py-1">{l.phone}</td>
                    <td className="py-1 text-muted-foreground">{l.assigned_to_name}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {/* Top Telecallers */}
        <div className="rounded-lg border p-4 space-y-3">
          <h2 className="font-semibold text-sm">Top Telecallers (This Month)</h2>
          {topTelecallers.length === 0 ? (
            <p className="text-xs text-muted-foreground">No data yet</p>
          ) : (
            <ul className="space-y-4">
              {topTelecallers.map((tc, i) => (
                <li key={tc.id} className="group relative flex items-center gap-4 p-2 rounded-lg hover:bg-slate-50 transition-colors border border-transparent hover:border-slate-100">
                  <div className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-xs font-bold shadow-sm ${
                    i === 0 ? 'bg-amber-100 text-amber-700 ring-2 ring-amber-50' : 
                    i === 1 ? 'bg-slate-100 text-slate-700' :
                    i === 2 ? 'bg-orange-50 text-orange-700' :
                    'bg-muted text-muted-foreground'
                  }`}>
                    {i + 1}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between gap-2 mb-1">
                      <p className="font-semibold text-sm truncate text-slate-800">{tc.full_name}</p>
                      <span className={`text-[10px] px-2 py-0.5 rounded-full font-bold shadow-sm ${
                        parseFloat(tc.conversion_rate) > 20 ? 'bg-emerald-100 text-emerald-700' :
                        parseFloat(tc.conversion_rate) > 10 ? 'bg-blue-100 text-blue-700' :
                        'bg-slate-100 text-slate-600'
                      }`}>
                        {tc.conversion_rate}%
                      </span>
                    </div>
                    <div className="flex items-center gap-3 text-[11px] text-slate-500">
                      <div className="flex items-center gap-1">
                        <span className="font-bold text-slate-900">{tc.conversions}</span>
                        <span className="text-slate-400 text-[10px]">Conversions</span>
                      </div>
                      <div className="w-1 h-1 rounded-full bg-slate-300" />
                      <div className="flex items-center gap-1">
                        <span className="font-bold text-slate-900">{tc.calls_made}</span>
                        <span className="text-slate-400 text-[10px]">Calls</span>
                      </div>
                    </div>
                    
                    {/* Subtle progress bar for conversion rate */}
                    <div className="mt-2 h-1 w-full bg-slate-100 rounded-full overflow-hidden">
                      <div 
                        className={`h-full transition-all duration-500 rounded-full ${
                          parseFloat(tc.conversion_rate) > 20 ? 'bg-emerald-500' :
                          parseFloat(tc.conversion_rate) > 10 ? 'bg-blue-500' :
                          'bg-slate-400'
                        }`}
                        style={{ width: `${Math.min(100, parseFloat(tc.conversion_rate))}%` }}
                      />
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>

      {/* Incentive section — only for telecallers */}
      {isLead && (
        <div className="rounded-lg border p-4 space-y-3">
          <h2 className="font-semibold text-sm">My Incentives (Month-wise)</h2>
          {incentiveHistory.length === 0 ? (
            <p className="text-xs text-muted-foreground">No incentive records found. Contact admin if this seems incorrect.</p>
          ) : (
            <table className="w-full text-sm">
              <thead>
                <tr className="text-xs text-muted-foreground border-b">
                  <th className="text-left py-1">Month</th>
                  <th className="text-right py-1">Incentive</th>
                  <th className="text-right py-1">Net Pay</th>
                  <th className="text-right py-1">Status</th>
                </tr>
              </thead>
              <tbody>
                {incentiveHistory.map((row, i) => (
                  <tr key={i} className="border-b last:border-0">
                    <td className="py-1.5 font-medium">{MONTH_NAMES[row.month - 1]} {row.year}</td>
                    <td className="py-1.5 text-right text-green-700">{fmt(row.incentive ?? 0)}</td>
                    <td className="py-1.5 text-right">{fmt(row.net ?? 0)}</td>
                    <td className="py-1.5 text-right">
                      <Badge variant={row.status === 'paid' ? 'default' : row.status === 'processed' ? 'secondary' : 'outline'} className="text-xs">
                        {row.status === 'paid' ? 'Paid' : row.status === 'processed' ? 'Processed' : 'Draft'}
                      </Badge>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}

      {/* Department-wise Stats (Admin Only) */}
      {!isLead && departmentStats.length > 0 && (
        <div className="rounded-lg border p-4 space-y-3">
          <h2 className="font-semibold text-sm">Department-wise Fees & Students</h2>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-xs text-muted-foreground border-b border-gray-100">
                  <th className="text-left font-medium pb-2">Department</th>
                  <th className="text-right font-medium pb-2">Total Students</th>
                  <th className="text-right font-medium pb-2">Fee Collected</th>
                  <th className="text-right font-medium pb-2">Pending Fees</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {departmentStats.map((dept) => (
                  <tr key={dept.id} className="group hover:bg-muted/30 transition-colors">
                    <td className="py-2.5 font-medium text-blue-600 hover:text-blue-800 hover:underline">
                      <Link href={`/backend?dept=${dept.id}`}>
                        {dept.name}
                      </Link>
                    </td>
                    <td className="py-2.5 text-right">{dept.total_students}</td>
                    <td className="py-2.5 text-right text-green-700 font-medium">{fmt(dept.collected_fee)}</td>
                    <td className="py-2.5 text-right text-amber-600 font-medium">{fmt(dept.pending_fee)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}
