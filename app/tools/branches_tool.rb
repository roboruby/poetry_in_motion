class BranchesTool < ApplicationTool
  description "List bank branches with their managers; filter by name fragment, city, or country. " \
              "Branches are reference data: the dataset links no accounts or customers to them."
  param :query, desc: "Branch or manager name fragment", required: false
  param :city, required: false
  param :country, required: false
  param :limit, type: :integer, desc: "Rows to return, default 25, max 200", required: false

  def execute(query: nil, city: nil, country: nil, limit: nil)
    scope = Branch.order(:branch_name)
    if query.present?
      term = "%#{Branch.sanitize_sql_like(query.to_s.strip)}%"
      scope = scope.where("branch_name LIKE :q OR manager_name LIKE :q", q: term)
    end
    scope = scope.where("LOWER(city) = ?", city.to_s.downcase) if city.present?
    scope = scope.where("LOWER(country) = ?", country.to_s.downcase) if country.present?
    rows = scope.limit(limit_of(limit, default: 25)).map do |branch|
      { id: branch.id, name: branch.branch_name, manager: branch.manager_name, city: branch.city.presence, country: branch.country.presence }
    end
    ok(total_matches: scope.count, returned: rows.size, rows: rows)
  end
end
