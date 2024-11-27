import UIKit
import SnapKit

class HearingHistoryViewController: UIViewController {
    
    // MARK: - Models
    struct HistoryItem {
        let date: Date
        let results: [HearingResult]
        let averageThreshold: Float
        let severity: String
        let aiAnalysis: String?
        var isExpanded: Bool = false
    }
    
    // MARK: - Properties
    private var historyItems: [HistoryItem] = []
    
    // MARK: - UI Elements
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("Test History", comment: "Title for test history screen")
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .white
        return label
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .white
        return button
    }()
    
    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.showsVerticalScrollIndicator = false
        return table
    }()
    
    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("No Test Records", comment: "Empty state message for test history")
        label.textColor = .gray
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16)
        label.isHidden = true
        return label
    }()
    
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = NSLocalizedString("Search by date or hearing level", comment: "Search bar placeholder")
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor = .white
        searchBar.barStyle = .black
        return searchBar
    }()
    
    private var filteredItems: [HistoryItem] = []
    private var isSearching: Bool = false
    
    private enum SortOption {
        case dateAscending
        case dateDescending
        case severityAscending
        case severityDescending
    }
    
    private var currentSortOption: SortOption = .dateDescending
    
    private let sortButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20)
        let image = UIImage(systemName: "arrow.up.arrow.down", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        loadHistoryData()
        setupNotifications()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadHistoryData()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0)
        
        view.addSubview(titleLabel)
        view.addSubview(closeButton)
        view.addSubview(tableView)
        view.addSubview(emptyStateLabel)
        view.addSubview(searchBar)
        view.addSubview(sortButton)
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.centerX.equalToSuperview()
        }
        
        closeButton.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.trailing.equalToSuperview().offset(-16)
            make.size.equalTo(44)
        }
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(searchBar.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        emptyStateLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        searchBar.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview()
        }
        
        sortButton.snp.makeConstraints { make in
            make.centerY.equalTo(closeButton)
            make.trailing.equalTo(closeButton.snp.leading).offset(-16)
            make.size.equalTo(44)
        }
        
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        sortButton.addTarget(self, action: #selector(showSortOptions), for: .touchUpInside)
        
        // 设置搜索栏代理
        searchBar.delegate = self
        searchBar.returnKeyType = .done  // 将返回键改为"完成"
        searchBar.enablesReturnKeyAutomatically = true  // 自动启用/禁用返回键
        searchBar.showsCancelButton = true  // 显示取消按钮
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(HistoryCell.self, forCellReuseIdentifier: "HistoryCell")
        tableView.register(HistoryDetailCell.self, forCellReuseIdentifier: "HistoryDetailCell")
    }
    
    private func loadHistoryData() {
        let defaults = UserDefaults.standard
        guard let historyData = defaults.array(forKey: "HearingTestHistory") as? [[String: Any]] else {
            print("No history data found")
            emptyStateLabel.isHidden = false
            return
        }
        
        print("Found history data: \(historyData.count) records")
        
        historyItems = historyData.compactMap { data in
            guard let date = data["date"] as? Date,
                  let resultsData = data["results"] as? [[String: Any]],
                  let averageThreshold = data["averageThreshold"] as? Float,
                  let severity = data["severity"] as? String else {
                print("Failed to parse history item: \(data)")
                return nil
            }
            
            let results = resultsData.compactMap { resultData -> HearingResult? in
                guard let frequency = resultData["frequency"] as? Int,
                      let threshold = resultData["threshold"] as? Float else {
                    print("Failed to parse result: \(resultData)")
                    return nil
                }
                return HearingResult(frequency: frequency, threshold: threshold)
            }
            
            let aiAnalysis = data["aiAnalysis"] as? String
            
            return HistoryItem(
                date: date,
                results: results,
                averageThreshold: averageThreshold,
                severity: severity,
                aiAnalysis: aiAnalysis,
                isExpanded: false
            )
        }
        
        print("Parsed history items: \(historyItems.count)")
        emptyStateLabel.isHidden = !historyItems.isEmpty
        tableView.reloadData()
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeleteItem(_:)),
            name: NSNotification.Name("DeleteHistoryItem"),
            object: nil
        )
        
        // 添加分享通知观察者
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShareItem(_:)),
            name: NSNotification.Name("ShareHistoryItem"),
            object: nil
        )
        
        // 添加查看结果的通知观察者
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleViewResult(_:)),
            name: NSNotification.Name("ViewHistoryResult"),
            object: nil
        )
    }
    
    @objc private func handleDeleteItem(_ notification: Notification) {
        guard let dateString = notification.userInfo?["date"] as? String,
              let index = historyItems.firstIndex(where: { 
                  let formatter = DateFormatter()
                  formatter.dateFormat = "MM-dd HH:mm"
                  return formatter.string(from: $0.date) == dateString
              }) else { return }
        
        let alert = UIAlertController(
            title: NSLocalizedString("Delete Record", comment: "Delete record alert title"),
            message: NSLocalizedString("Are you sure you want to delete this record?", comment: "Delete record alert message"),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel button title"), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: "Delete button title"), style: .destructive) { [weak self] _ in
            self?.deleteHistoryItem(at: index)
        })
        
        present(alert, animated: true)
    }
    
    private func deleteHistoryItem(at index: Int) {
        historyItems.remove(at: index)
        
        // 更新 UserDefaults
        let defaults = UserDefaults.standard
        let updatedHistory = historyItems.map { item -> [String: Any] in
            return [
                "date": item.date,
                "results": item.results.map { ["frequency": $0.frequency, "threshold": $0.threshold] },
                "averageThreshold": item.averageThreshold,
                "severity": item.severity
            ]
        }
        defaults.set(updatedHistory, forKey: "HearingTestHistory")
        
        // 更新 UI
        tableView.performBatchUpdates({
            tableView.deleteSections(IndexSet(integer: index), with: .fade)
        })
        
        // 检查是否需要显示空状态
        emptyStateLabel.isHidden = !historyItems.isEmpty
    }
    
    @objc private func showSortOptions() {
        let alertController = UIAlertController(
            title: NSLocalizedString("Sort By", comment: "Sort options title"),
            message: nil,
            preferredStyle: .actionSheet
        )
        
        let dateDescAction = UIAlertAction(
            title: NSLocalizedString("Date (Latest)", comment: "Sort by date descending"),
            style: .default
        ) { [weak self] _ in
            self?.currentSortOption = .dateDescending
            self?.sortAndReloadData()
        }
        
        let dateAscAction = UIAlertAction(
            title: NSLocalizedString("Date (Oldest)", comment: "Sort by date ascending"),
            style: .default
        ) { [weak self] _ in
            self?.currentSortOption = .dateAscending
            self?.sortAndReloadData()
        }
        
        let severityAscAction = UIAlertAction(
            title: NSLocalizedString("Severity (Low to High)", comment: "Sort by severity ascending"),
            style: .default
        ) { [weak self] _ in
            self?.currentSortOption = .severityAscending
            self?.sortAndReloadData()
        }
        
        let severityDescAction = UIAlertAction(
            title: NSLocalizedString("Severity (High to Low)", comment: "Sort by severity descending"),
            style: .default
        ) { [weak self] _ in
            self?.currentSortOption = .severityDescending
            self?.sortAndReloadData()
        }
        
        let cancelAction = UIAlertAction(
            title: NSLocalizedString("Cancel", comment: "Cancel button"),
            style: .cancel
        )
        
        [dateDescAction, dateAscAction, severityAscAction, severityDescAction, cancelAction].forEach {
            alertController.addAction($0)
        }
        
        present(alertController, animated: true)
    }
    
    private func sortAndReloadData() {
        let items = isSearching ? filteredItems : historyItems
        
        switch currentSortOption {
        case .dateDescending:
            historyItems.sort { $0.date > $1.date }
        case .dateAscending:
            historyItems.sort { $0.date < $1.date }
        case .severityAscending:
            historyItems.sort { getSeverityOrder($0.severity) < getSeverityOrder($1.severity) }
        case .severityDescending:
            historyItems.sort { getSeverityOrder($0.severity) > getSeverityOrder($1.severity) }
        }
        
        if isSearching {
            filteredItems = items
        }
        
        tableView.reloadData()
    }
    
    private func getSeverityOrder(_ severity: String) -> Int {
        switch severity {
        case "NORMAL": return 0
        case "MILD": return 1
        case "MODERATE": return 2
        case "SEVERE": return 3
        case "PROFOUND": return 4
        default: return 5
        }
    }
    
    private func filterItems(with searchText: String) {
        filteredItems = historyItems.filter { item in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM-dd HH:mm"
            let dateString = dateFormatter.string(from: item.date)
            
            let severityText = NSLocalizedString(item.severity, comment: "Hearing level severity")
            
            return dateString.localizedCaseInsensitiveContains(searchText) ||
                   severityText.localizedCaseInsensitiveContains(searchText)
        }
        
        tableView.reloadData()
        
        // 显示或隐藏"无匹配结果"标签
        if isSearching && filteredItems.isEmpty {
            emptyStateLabel.text = NSLocalizedString("No Matching Results", comment: "No search results")
            emptyStateLabel.isHidden = false
        } else {
            emptyStateLabel.text = NSLocalizedString("No Test Records", comment: "No test records")
            emptyStateLabel.isHidden = !historyItems.isEmpty
        }
    }
    
    // 添加处理分享的方法
    @objc private func handleShareItem(_ notification: Notification) {
        guard let item = notification.userInfo?["item"] as? HistoryItem else { return }
        
        // 准备分享数据
        var shareText = NSLocalizedString("Hearing Test Results", comment: "Share text title") + "\n"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        shareText += NSLocalizedString("Test Time", comment: "Share text test time") + ": \(formatter.string(from: item.date))\n\n"
        
        shareText += NSLocalizedString("Frequency (Hz) | Threshold (dB)", comment: "Share text frequency threshold") + "\n"
        shareText += "---------|----------\n"
        
        for result in item.results {
            shareText += String(format: "%8d | %7.1f\n", result.frequency, result.threshold)
        }
        
        shareText += "\n" + NSLocalizedString("Average Hearing Loss", comment: "Share text average hearing loss") + ": \(String(format: "%.1f", item.averageThreshold))dB\n"
        shareText += NSLocalizedString("Hearing Level", comment: "Share text hearing level") + ": \(item.severity)\n"
        
        // 创建分享菜单
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        // 在 iPad 上需要设置弹出位置
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = view
            popoverController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        present(activityVC, animated: true)
    }
    
    @objc private func handleViewResult(_ notification: Notification) {
        guard let dateString = notification.userInfo?["date"] as? String,
              let index = historyItems.firstIndex(where: { 
                  let formatter = DateFormatter()
                  formatter.dateFormat = "MM-dd HH:mm"
                  return formatter.string(from: $0.date) == dateString
              }) else { return }
        
        let item = historyItems[index]
        
        // 创建结果页面并传递数据
        let resultVC = HearingResultViewController()
        resultVC.modalPresentationStyle = .fullScreen
        resultVC.setResults(item.results)
        present(resultVC, animated: true)
    }
}

// MARK: - UITableViewDelegate & DataSource
extension HearingHistoryViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return isSearching ? filteredItems.count : historyItems.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let items = isSearching ? filteredItems : historyItems
        return items[section].isExpanded ? 2 : 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let items = isSearching ? filteredItems : historyItems
        let item = items[indexPath.section]
        
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryCell", for: indexPath) as! HistoryCell
            cell.configure(with: item)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryDetailCell", for: indexPath) as! HistoryDetailCell
            cell.configure(with: item)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            if let cell = tableView.cellForRow(at: indexPath) as? HistoryCell {
                cell.animateTapFeedback()
            }
            
            // 根据搜索状态选择正确的数据源
            if isSearching {
                filteredItems[indexPath.section].isExpanded.toggle()
                let isExpanded = filteredItems[indexPath.section].isExpanded
                
                // 同步原始数据的展开状态
                if let originalIndex = historyItems.firstIndex(where: { item in
                    item.date == filteredItems[indexPath.section].date
                }) {
                    historyItems[originalIndex].isExpanded = isExpanded
                }
            } else {
                historyItems[indexPath.section].isExpanded.toggle()
                let isExpanded = historyItems[indexPath.section].isExpanded
            }
            
            // 使用更平滑的动画
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.5,
                options: .curveEaseInOut,
                animations: {
                    if let cell = tableView.cellForRow(at: indexPath) as? HistoryCell {
                        cell.rotateArrow(isExpanded: self.isSearching ? 
                            self.filteredItems[indexPath.section].isExpanded :
                            self.historyItems[indexPath.section].isExpanded)
                    }
                    
                    tableView.performBatchUpdates({
                        tableView.reloadSections(IndexSet(integer: indexPath.section), with: .fade)
                    })
                }
            )
            
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.alpha = 0
        cell.transform = CGAffineTransform(translationX: 0, y: 20)
        
        UIView.animate(
            withDuration: 0.4,
            delay: 0.05 * Double(indexPath.row),
            options: [.curveEaseOut],
            animations: {
                cell.alpha = 1
                cell.transform = .identity
            }
        )
    }
}

// MARK: - Custom Cells
class HistoryCell: UITableViewCell {
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        view.layer.cornerRadius = 16
        
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 6)
        view.layer.shadowOpacity = 0.5
        view.layer.shadowRadius = 8
        
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        return view
    }()
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        return label
    }()
    
    private let severityLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        return label
    }()
    
    private let arrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let deleteButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16)
        let image = UIImage(systemName: "trash", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = UIColor(red: 0.902, green: 0.298, blue: 0.235, alpha: 1.0)
        return button
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(containerView)
        containerView.addSubview(dateLabel)
        containerView.addSubview(severityLabel)
        containerView.addSubview(arrowImageView)
        containerView.addSubview(deleteButton)
        
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
            make.height.equalTo(80)
        }
        
        dateLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.width.lessThanOrEqualTo(containerView.snp.width).multipliedBy(0.35)
        }
        
        severityLabel.snp.makeConstraints { make in
            make.trailing.equalTo(deleteButton.snp.leading).offset(-16)
            make.centerY.equalToSuperview()
            make.width.equalTo(100)
            make.height.equalTo(32)
        }
        
        arrowImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }
        
        deleteButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(arrowImageView.snp.leading).offset(-16)
            make.size.equalTo(32)
        }
        
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
    }
    
    func animateTapFeedback() {
        UIView.animate(withDuration: 0.1, animations: {
            self.containerView.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.containerView.transform = .identity
            }
        }
    }
    
    func configure(with item: HearingHistoryViewController.HistoryItem) {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        dateLabel.text = formatter.string(from: item.date)
        
        severityLabel.text = NSLocalizedString(item.severity, comment: "Hearing level severity")
        severityLabel.backgroundColor = getSeverityColor(for: item.severity)
        
        let imageName = item.isExpanded ? "chevron.up" : "chevron.down"
        arrowImageView.image = UIImage(systemName: imageName)
        arrowImageView.transform = item.isExpanded ? CGAffineTransform(rotationAngle: .pi) : .identity
    }
    
    private func getSeverityColor(for severity: String) -> UIColor {
        switch severity {
        case "NORMAL": return UIColor(red: 0.196, green: 0.843, blue: 0.294, alpha: 1.0)
        case "MILD": return UIColor(red: 0.988, green: 0.812, blue: 0.157, alpha: 1.0)
        case "MODERATE": return UIColor(red: 0.902, green: 0.494, blue: 0.133, alpha: 1.0)
        case "SEVERE": return UIColor(red: 0.902, green: 0.298, blue: 0.235, alpha: 1.0)
        case "PROFOUND": return UIColor(red: 0.584, green: 0.235, blue: 0.902, alpha: 1.0)
        default: return .gray
        }
    }
    
    @objc private func deleteButtonTapped() {
        NotificationCenter.default.post(
            name: NSNotification.Name("DeleteHistoryItem"),
            object: nil,
            userInfo: ["date": dateLabel.text ?? ""]
        )
    }
    
    func rotateArrow(isExpanded: Bool) {
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5,
            options: .curveEaseInOut,
            animations: {
                self.arrowImageView.transform = isExpanded ? 
                    CGAffineTransform(rotationAngle: .pi) : .identity
            }
        )
    }
}

class HistoryDetailCell: UITableViewCell {
    // 添加属性来存储当前项
    private var currentItem: HearingHistoryViewController.HistoryItem?
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        view.layer.cornerRadius = 16
        
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        return view
    }()
    
    private let averageLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        return label
    }()
    
    private let frequencyStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        return stack
    }()
    
    private let viewResultButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16)
        let image = UIImage(systemName: "chart.xyaxis.line", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        return button
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(containerView)
        containerView.addSubview(averageLabel)
        containerView.addSubview(frequencyStackView)
        containerView.addSubview(viewResultButton)
        
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16))
        }
        
        averageLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(20)
        }
        
        frequencyStackView.snp.makeConstraints { make in
            make.top.equalTo(averageLabel.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().offset(-20)
        }
        
        viewResultButton.snp.makeConstraints { make in
            make.top.equalTo(averageLabel)
            make.trailing.equalToSuperview().offset(-20)
        }
        
        viewResultButton.addTarget(self, action: #selector(viewResultButtonTapped), for: .touchUpInside)
    }
    
    func configure(with item: HearingHistoryViewController.HistoryItem) {
        // 保存当前项
        self.currentItem = item
        
        averageLabel.text = String(format: NSLocalizedString("Average Hearing Loss", comment: "Average hearing loss label") + ": %.1f dB", item.averageThreshold)
        
        frequencyStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for result in item.results {
            let label = UILabel()
            let frequency = result.frequency >= 1000 ? 
                String(format: "%.1fk", Float(result.frequency) / 1000) : 
                "\(result.frequency)"
            label.text = "\(frequency)Hz\n\(Int(result.threshold))dB"
            label.textColor = .white
            label.font = .systemFont(ofSize: 14, weight: .medium)
            label.numberOfLines = 2
            label.textAlignment = .center
            frequencyStackView.addArrangedSubview(label)
        }
    }
    
    @objc private func viewResultButtonTapped() {
        guard let item = currentItem else { return }
        
        // 使用 DateFormatter 来格式化当前项的日期
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        let dateString = formatter.string(from: item.date)
        
        NotificationCenter.default.post(
            name: NSNotification.Name("ViewHistoryResult"),
            object: nil,
            userInfo: ["date": dateString]
        )
    }
}

// 添加搜索功能
extension HearingHistoryViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let text = searchText.trimmingCharacters(in: .whitespaces)
        isSearching = !text.isEmpty
        
        if isSearching {
            filterItems(with: text)
        }
        
        // 更新 UI
        tableView.reloadData()
        
        // 更新空状态标签
        emptyStateLabel.text = isSearching && filteredItems.isEmpty ? 
            NSLocalizedString("No Matching Results", comment: "No matching results label") : NSLocalizedString("No Test Records", comment: "No test records label")
        emptyStateLabel.isHidden = isSearching ? 
            !filteredItems.isEmpty : !historyItems.isEmpty
    }
    
    func searchBar(_ searchBar: UISearchBar, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // 如果输入回车键，收起键盘
        if text == "\n" {
            searchBar.resignFirstResponder()
            return false
        }
        return true
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        isSearching = false
        tableView.reloadData()
    }
    
    // 添加点击空白处收起键盘的功能
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
} 
