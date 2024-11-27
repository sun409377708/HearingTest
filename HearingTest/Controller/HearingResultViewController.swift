import UIKit
import DGCharts
import SnapKit

// 添加听力测试结果模型
struct HearingResult {
    let frequency: Int
    let threshold: Float
    
    // 获取听力损失程度
    func getSeverityLevel() -> SeverityLevel {
        switch threshold {
        case ..<20:
            return .normal
        case 20..<40:
            return .mild
        case 40..<60:
            return .moderate
        case 60..<80:
            return .severe
        default:
            return .profound
        }
    }
}

// 添加听力损失程度枚举
enum SeverityLevel: String {
    case normal = "NORMAL"
    case mild = "MILD"
    case moderate = "MODERATE"
    case severe = "SEVERE"
    case profound = "PROFOUND"
    
    var localizedString: String {
        return NSLocalizedString(self.rawValue, comment: "Hearing level severity")
    }
    
    var color: UIColor {
        switch self {
        case .normal: return UIColor(red: 0.196, green: 0.843, blue: 0.294, alpha: 1.0)
        case .mild: return UIColor(red: 0.988, green: 0.812, blue: 0.157, alpha: 1.0)
        case .moderate: return UIColor(red: 0.902, green: 0.494, blue: 0.133, alpha: 1.0)
        case .severe: return UIColor(red: 0.902, green: 0.298, blue: 0.235, alpha: 1.0)
        case .profound: return UIColor(red: 0.584, green: 0.235, blue: 0.902, alpha: 1.0)
        }
    }
    
    static func from(threshold: Float) -> SeverityLevel {
        switch threshold {
        case ..<20: return .normal
        case 20..<40: return .mild
        case 40..<60: return .moderate
        case 60..<80: return .severe
        default: return .profound
        }
    }
}

class HearingResultViewController: UIViewController, ChartViewDelegate {
    
    // MARK: - Properties
    private var results: [HearingResult] = []
    private var isShowingValues = true
    private var severityLabel: UILabel!
    private let deepSeekService = DeepSeekService()
    
    // 在 Properties 部分添加 loading 视图
    private let loadingView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        view.isHidden = true
        return view
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        return indicator
    }()
    
    private let loadingLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("LOADING_ANALYSIS", comment: "Loading message for AI analysis")
        label.textColor = .white
        label.font = .systemFont(ofSize: 16)
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - UI Elements
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("HEARING_RESULT_TITLE", comment: "Title for hearing test results screen")
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        let formatter = DateFormatter()
        formatter.dateFormat = "yy.MM月 yyyy; HH:mm"
        label.text = formatter.string(from: Date())
        label.font = .systemFont(ofSize: 16)
        label.textAlignment = .center
        label.textColor = .lightGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let chartView: LineChartView = {
        let chartView = LineChartView()
        chartView.backgroundColor = .clear
        chartView.rightAxis.enabled = false

        // 配置X轴
        let xAxis = chartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.labelTextColor = .lightGray
        xAxis.gridColor = .darkGray
        xAxis.axisLineColor = .darkGray
        xAxis.valueFormatter = IndexAxisValueFormatter(values: ["250", "500", "1k", "2k", "4k", "8k"])
        xAxis.setLabelCount(6, force: true)
        xAxis.drawLabelsEnabled = true
        xAxis.axisMinimum = 0  // 稍微留点边距
        xAxis.axisMaximum = 5
        xAxis.granularity = 1

        // 配置Y轴
        let leftAxis = chartView.leftAxis
        leftAxis.labelTextColor = .lightGray
        leftAxis.gridColor = .darkGray
        leftAxis.axisLineColor = .darkGray
        leftAxis.axisMinimum = -10
        leftAxis.axisMaximum = 90
        leftAxis.inverted = true
        leftAxis.labelCount = 11
        
        // 增加图表边距
        chartView.extraTopOffset = 40
        chartView.extraLeftOffset = 15
        chartView.extraRightOffset = 15

        chartView.legend.enabled = false
        chartView.translatesAutoresizingMaskIntoConstraints = false
        
        // 启用点击交互
        chartView.highlightPerTapEnabled = true
        
        // 修改动画效果，使其更流畅
        chartView.animate(xAxisDuration: 1.0, yAxisDuration: 1.0, easingOption: .easeInOutCubic)
        
        // 添加手势缩放
        chartView.pinchZoomEnabled = true
        chartView.doubleTapToZoomEnabled = true
        
        // 添加图表描述
        let description = Description()
        description.text = "频率 (Hz)"
        description.textColor = .lightGray
        chartView.chartDescription = description
        
        // 添加渐变效果
        let gradientColors = [UIColor.systemBlue.cgColor, UIColor.systemBlue.withAlphaComponent(0.1).cgColor]
        let gradient = CGGradient(colorsSpace: nil, colors: gradientColors as CFArray, locations: nil)!
        
        let dataSet = LineChartDataSet(entries: [])
        dataSet.fillAlpha = 0.3
        dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
        dataSet.drawFilledEnabled = true
        
        // 优化网格线
        leftAxis.gridLineDashLengths = [4, 2]  // 虚线网格
        xAxis.gridLineDashLengths = [4, 2]
        
        return chartView
    }()
    
    private let toggleValuesButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20)
        let image = UIImage(systemName: "eye.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let exportButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20)
        let image = UIImage(systemName: "square.and.arrow.up", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        return button
    }()
    
    private let analysisButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("AI_ANALYSIS", comment: "AI analysis button title"), for: .normal)
        button.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 16
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSeverityView()
        setupAccessibility()
        chartView.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !results.isEmpty {
            updateChartData()
            updateSeverityLabel()
        }
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0)
        
        view.addSubview(titleLabel)
        view.addSubview(dateLabel)
        view.addSubview(closeButton)
        view.addSubview(chartView)
        view.addSubview(toggleValuesButton)
        view.addSubview(exportButton)
        view.addSubview(analysisButton)
        
        // 添加 loading 视图
        view.addSubview(loadingView)
        loadingView.addSubview(activityIndicator)
        loadingView.addSubview(loadingLabel)
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.centerX.equalToSuperview()
        }
        
        dateLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
        }
        
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.size.equalTo(44)
        }
        
        toggleValuesButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.leading.equalToSuperview().offset(16)
            make.size.equalTo(44)
        }
        
        exportButton.snp.makeConstraints { make in
            make.centerY.equalTo(toggleValuesButton)
            make.leading.equalTo(toggleValuesButton.snp.trailing).offset(16)
            make.size.equalTo(44)
        }
        
        chartView.snp.makeConstraints { make in
            make.top.equalTo(dateLabel.snp.bottom).offset(32)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.height.equalTo(300)
        }
        
        analysisButton.snp.makeConstraints { make in
            make.top.equalTo(chartView.snp.bottom).offset(24)
            make.centerX.equalToSuperview()
            make.width.equalTo(120)
            make.height.equalTo(44)
        }
        
        // 添加 loading 视图约束
        loadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        activityIndicator.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-20)
        }
        
        loadingLabel.snp.makeConstraints { make in
            make.top.equalTo(activityIndicator.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
        }
        
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        toggleValuesButton.addTarget(self, action: #selector(toggleValuesButtonTapped), for: .touchUpInside)
        exportButton.addTarget(self, action: #selector(exportButtonTapped), for: .touchUpInside)
        analysisButton.addTarget(self, action: #selector(analysisButtonTapped), for: .touchUpInside)
    }
    
    private func setupSeverityView() {
        let severityView = UIView()
        severityView.backgroundColor = UIColor.systemGray6.withAlphaComponent(0.3)
        severityView.layer.cornerRadius = 12
        view.addSubview(severityView)
        
        severityLabel = UILabel()
        severityLabel.text = "你"
        severityLabel.textAlignment = .center
        severityLabel.backgroundColor = .systemPurple
        severityLabel.textColor = .white
        severityLabel.layer.cornerRadius = 15
        severityLabel.clipsToBounds = true
        severityView.addSubview(severityLabel)
        
        severityView.snp.makeConstraints { make in
            make.top.equalTo(analysisButton.snp.bottom).offset(24)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.height.equalTo(80)
        }
        
        severityLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(100)
            make.height.equalTo(30)
        }
        
        
        // 添加听力等级说明视图
        let levelDescriptionView = UIView()
        levelDescriptionView.backgroundColor = .clear
        view.addSubview(levelDescriptionView)
        
        let levels = [
            (SeverityLevel.normal, "0-20dB"),
            (SeverityLevel.mild, "20-40dB"),
            (SeverityLevel.moderate, "40-60dB"),
            (SeverityLevel.severe, "60-80dB"),
            (SeverityLevel.profound, "80dB+")
        ]
        
        var previousLabel: UILabel?
        for (level, range) in levels {
            let container = UIView()
            container.backgroundColor = .clear
            
            let dot = UIView()
            dot.backgroundColor = level.color
            dot.layer.cornerRadius = 4
            
            let label = UILabel()
            label.text = "\(level.localizedString) (\(range))"
            label.font = .systemFont(ofSize: 12)
            label.textColor = .lightGray
            
            container.addSubview(dot)
            container.addSubview(label)
            levelDescriptionView.addSubview(container)
            
            container.snp.makeConstraints { make in
                if let previous = previousLabel {
                    make.top.equalTo(previous.snp.bottom).offset(8)
                } else {
                    make.top.equalToSuperview()
                }
                make.leading.equalToSuperview()
                make.height.equalTo(20)
            }
            
            dot.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.equalToSuperview()
                make.size.equalTo(8)
            }
            
            label.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.equalTo(dot.snp.trailing).offset(8)
            }
            
            previousLabel = label
        }
        
        levelDescriptionView.snp.makeConstraints { make in
            make.top.equalTo(severityView.snp.bottom).offset(24)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }
    }
    
    func setResults(_ results: [HearingResult]) {
        self.results = results
        
        // 确保视图已加载
        if isViewLoaded {
            updateChartData()
            saveResults()
            updateSeverityLabel()
        }
    }
    
    private func updateChartData() {
        let entries = results.enumerated().map { index, result in
            ChartDataEntry(x: Double(index), y: Double(result.threshold))
        }
        
        let dataSet = LineChartDataSet(entries: entries, label: "听力曲线")
        dataSet.setColor(.systemBlue)
        dataSet.setCircleColor(.systemBlue)
        dataSet.circleRadius = 4
        dataSet.drawCircleHoleEnabled = false
        dataSet.lineWidth = 2
        dataSet.mode = .linear
        dataSet.drawValuesEnabled = isShowingValues
        dataSet.valueFont = .systemFont(ofSize: 12)
        dataSet.valueTextColor = .white
        
        let data = LineChartData(dataSets: [dataSet])
        data.setValueFormatter(DefaultValueFormatter(block: { (value, _, _, _) in
            return String(format: "%.f dB", value)
        }))
        
        chartView.data = data
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func toggleValuesButtonTapped() {
        isShowingValues.toggle()
        
        // 更按钮图标
        let config = UIImage.SymbolConfiguration(pointSize: 20)
        let imageName = isShowingValues ? "eye.fill" : "eye.slash.fill"
        toggleValuesButton.setImage(UIImage(systemName: imageName, withConfiguration: config), for: .normal)
        
        // 更新图表显示
        if let dataSet = chartView.data?.dataSets.first as? LineChartDataSet {
            dataSet.drawValuesEnabled = isShowingValues
            chartView.data?.notifyDataChanged()
            chartView.notifyDataSetChanged()
        }
    }
    
    @objc private func exportButtonTapped() {
        // 准备导出数据
        var exportText = NSLocalizedString("HEARING_TEST_RESULTS", comment: "Hearing test results") + "\n"
        exportText += NSLocalizedString("TEST_TIME", comment: "Test time") + ": \(dateLabel.text ?? "")\n\n"
        
        exportText += NSLocalizedString("FREQUENCY_HZ", comment: "Frequency (Hz)") + " | " + NSLocalizedString("THRESHOLD_DB", comment: "Threshold (dB)") + "\n"
        exportText += "---------|----------\n"
        
        for result in results {
            exportText += String(format: "%8d | %7.1f\n", result.frequency, result.threshold)
        }
        
        exportText += "\n" + NSLocalizedString("AVERAGE_HEARING_LOSS", comment: "Average hearing loss") + ": \(calculateAverageThreshold())dB\n"
        exportText += NSLocalizedString("HEARING_LEVEL", comment: "Hearing level") + ": \(severityLabel.text ?? "")\n"
        
        // 生成图表图片
        let renderer = UIGraphicsImageRenderer(bounds: chartView.bounds)
        let image = renderer.image { context in
            chartView.layer.render(in: context.cgContext)
        }
        
        // 同时分享文本和图片
        let activityVC = UIActivityViewController(
            activityItems: [exportText, image],
            applicationActivities: nil
        )
        present(activityVC, animated: true)
    }
    
    private func calculateAverageThreshold() -> Float {
        let average = results.map { $0.threshold }.reduce(0, +) / Float(results.count)
        return round(average * 10) / 10  // 保留一位小数
    }
    
    // MARK: - ChartViewDelegate
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        // 可以在这里添加其他交互效果，比如高亮显示等
    }
    
    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        // 可以里添加取高等效果
    }
    
    // 添加保存结果的方法
    private func saveResults() {
        let defaults = UserDefaults.standard
        let testData: [String: Any] = [
            "date": Date(),
            "results": results.map { ["frequency": $0.frequency, "threshold": $0.threshold] },
            "averageThreshold": calculateAverageThreshold(),
            "severity": severityLabel.text ?? "",
            "aiAnalysis": "" // 初始为空，等 AI 分析完成后更新
        ]
        
        // 获取现有历史记录
        var history = defaults.array(forKey: "HearingTestHistory") as? [[String: Any]] ?? []
        history.append(testData)
        
        // 只保留最近的10次记录
        if history.count > 10 {
            history.removeFirst(history.count - 10)
        }
        
        defaults.set(history, forKey: "HearingTestHistory")
        defaults.synchronize()
    }
    
    private func setupAccessibility() {
        chartView.isAccessibilityElement = true
        chartView.accessibilityLabel = NSLocalizedString("HEARING_TEST_RESULTS_CHART", comment: "Hearing test results chart")
        
        let summary = results.map { NSLocalizedString("FREQUENCY_HZ", comment: "Frequency (Hz)") + "\($0.frequency)赫兹，阈值\($0.threshold)分贝" }
            .joined(separator: "；")
        chartView.accessibilityHint = summary
        
        toggleValuesButton.accessibilityLabel = NSLocalizedString("TOGGLE_VALUES", comment: "Toggle values")
        exportButton.accessibilityLabel = NSLocalizedString("EXPORT_RESULTS", comment: "Export results")
        analysisButton.accessibilityLabel = NSLocalizedString("AI_ANALYSIS", comment: "AI analysis")
    }
    
    private func updateSeverityLabel() {
        guard !results.isEmpty, let label = severityLabel else { return }
        
        // 计算平均听力损失
        let averageThreshold = results.map { $0.threshold }.reduce(0, +) / Float(results.count)
        let severityLevel = HearingResult(frequency: 0, threshold: averageThreshold).getSeverityLevel()
        
        // 更新 UI
        label.backgroundColor = severityLevel.color
        label.text = severityLevel.localizedString
    }
    
    // 添加按钮点击事件处理方法
    @objc private func analysisButtonTapped() {
        // 生成图表图片
        let renderer = UIGraphicsImageRenderer(bounds: chartView.bounds)
        let chartImage = renderer.image { context in
            chartView.layer.render(in: context.cgContext)
        }
        
        // 检查是否有缓存的分析结果
        let defaults = UserDefaults.standard
        if let history = defaults.array(forKey: "HearingTestHistory") as? [[String: Any]],
           let lastResult = history.last,
           let savedAnalysis = lastResult["aiAnalysis"] as? [String: String],  // 改为字典类型
           !savedAnalysis.isEmpty,
           let currentLang = Locale.current.languageCode,  // 获取当前语言
           let analysis = savedAnalysis[currentLang] {  // 获取对应语言的分析结果
            
            print("Found cached analysis for language: \(currentLang)")
            
            // 直接显示缓存的分析结果
            let analysisVC = HearingAnalysisViewController(
                analysis: analysis,
                averageThreshold: calculateAverageThreshold(),
                severity: severityLabel.text ?? "",
                date: Date(),
                chartImage: chartImage
            )
            analysisVC.modalPresentationStyle = .fullScreen
            present(analysisVC, animated: true)
            return
        }
        
        print("No cached analysis found, requesting new analysis...")
        
        // 如果没有缓存，则请求新的分析
        showLoading()
        
        // 根据当前语言设置提示语
        let currentLang = Locale.current.languageCode ?? "en"
        var prompt = ""
        
        if currentLang == "zh" {
            prompt = "请分析以下听力测试结果：\n"
            for result in results {
                prompt += "频率 \(result.frequency)Hz: \(result.threshold)dB\n"
            }
            prompt += "\n平均听力损失：\(calculateAverageThreshold())dB\n"
            prompt += "听力等级：\(severityLabel.text ?? "")\n"
            prompt += "\n请用中文给出专业的分析和建议。"
        } else {
            prompt = "Please analyze the following hearing test results:\n"
            for result in results {
                prompt += "Frequency \(result.frequency)Hz: \(result.threshold)dB\n"
            }
            prompt += "\nAverage hearing loss: \(calculateAverageThreshold())dB\n"
            prompt += "Hearing level: \(severityLabel.text ?? "")\n"
            prompt += "\nPlease provide professional analysis and suggestions in English."
        }
        
        Task {
            do {
                let analysis = try await deepSeekService.generateResponse(prompt: prompt)
                
                // 更新存储的分析结果
                if var history = defaults.array(forKey: "HearingTestHistory") as? [[String: Any]],
                   var lastResult = history.last {
                    // 创建或更新分析结果字典
                    var analysisDict = lastResult["aiAnalysis"] as? [String: String] ?? [:]
                    analysisDict[currentLang] = analysis
                    lastResult["aiAnalysis"] = analysisDict
                    history[history.count - 1] = lastResult
                    defaults.set(history, forKey: "HearingTestHistory")
                    defaults.synchronize()
                    
                    print("Analysis saved to cache for language: \(currentLang)")
                }
                
                DispatchQueue.main.async {
                    self.hideLoading()
                    let analysisVC = HearingAnalysisViewController(
                        analysis: analysis,
                        averageThreshold: self.calculateAverageThreshold(),
                        severity: self.severityLabel.text ?? "",
                        date: Date(),
                        chartImage: chartImage
                    )
                    analysisVC.modalPresentationStyle = .fullScreen
                    self.present(analysisVC, animated: true)
                }
            } catch {
                DispatchQueue.main.async {
                    self.hideLoading()
                    self.showAlert(title: NSLocalizedString("ANALYSIS_FAILED", comment: "Analysis failed"), message: error.localizedDescription)
                }
            }
        }
    }
    
    // 在 HearingResultViewController 类中添加 showAlert 方法
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default))
        present(alert, animated: true)
    }
    
    // 添加显示和隐藏 loading 的方法
    private func showLoading() {
        loadingView.isHidden = false
        activityIndicator.startAnimating()
    }
    
    private func hideLoading() {
        loadingView.isHidden = true
        activityIndicator.stopAnimating()
    }
}
