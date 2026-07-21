export default function DashboardLoading() {
  return (
    <div aria-label="Loading administration data" aria-busy="true">
      <div className="loading-heading" />
      <div className="loading-copy" />
      <div className="metric-grid loading-metrics">
        {Array.from({ length: 4 }, (_, index) => (
          <div className="loading-card" key={index} />
        ))}
      </div>
      <div className="dashboard-grid">
        <div className="loading-panel" />
        <div className="loading-panel" />
      </div>
    </div>
  );
}
