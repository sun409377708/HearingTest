import UIKit
import SnapKit

class HearingAnalysisViewController: UIViewController {
    
    // MARK: - Properties
    private let analysis: String
    private let averageThreshold: Float
    private let severity: String
    private let date: Date
    private let chartImage: UIImage
    
    // MARK: - UI Elements
    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .grouped)
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.showsVerticalScrollIndicator = false
        return table
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20)
        let image = UIImage(systemName: "xmark.circle.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        return button
    }()
    
    private let shareButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20)
        let image = UIImage(systemName: "square.and.arrow.up", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        return button
    }()
    
    private let chartImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        return imageView
    }()
    
    // MARK: - Initialization
    init(analysis: String, averageThreshold: Float, severity: String, date: Date, chartImage: UIImage) {
        self.analysis = analysis
        self.averageThreshold = averageThreshold
        self.severity = severity
        self.date = date
        self.chartImage = chartImage
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0)
        
        view.addSubview(tableView)
        view.addSubview(closeButton)
        view.addSubview(shareButton)
        
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.leading.equalToSuperview().offset(16)
            make.size.equalTo(44)
        }
        
        shareButton.snp.makeConstraints { make in
            make.top.equalTo(closeButton)
            make.trailing.equalToSuperview().offset(-16)
            make.size.equalTo(44)
        }
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(closeButton.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        
        // 设置表头视图的内边距
        tableView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)
    }
    
    // MARK: - Actions
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func shareButtonTapped() {
        // 计算内容的实际高度
        let contentLabel = UILabel()
        contentLabel.text = analysis
        contentLabel.font = .systemFont(ofSize: 16)
        contentLabel.numberOfLines = 0
        let maxWidth = view.bounds.width - 80 // 考虑左右边距
        let contentSize = contentLabel.sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        
        // 计算总高度
        let headerHeight: CGFloat = 80
        let infoCardHeight: CGFloat = 150
        let spacing: CGFloat = 16
        let titleHeight: CGFloat = 24
        let analysisCardHeight = contentSize.height + titleHeight + 48 // 添加标题高度和内边距
        
        let totalHeight = headerHeight + infoCardHeight + spacing + analysisCardHeight + spacing * 3
        
        // 创建内容视图
        let contentView = UIView(frame: CGRect(
            x: 0,
            y: 0,
            width: view.bounds.width,
            height: totalHeight
        ))
        contentView.backgroundColor = view.backgroundColor
        
        // 创建标题部分
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: contentView.bounds.width, height: headerHeight))
        headerView.backgroundColor = .clear
        
        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("Hearing Analysis Report", comment: "Title for hearing analysis report")
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        
        let dateLabel = UILabel()
        dateLabel.text = formatDate(date)
        dateLabel.font = .systemFont(ofSize: 14)
        dateLabel.textColor = .lightGray
        dateLabel.textAlignment = .center
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(dateLabel)
        
        titleLabel.frame = CGRect(x: 16, y: 16, width: headerView.bounds.width - 32, height: 30)
        dateLabel.frame = CGRect(x: 16, y: titleLabel.frame.maxY + 4, width: headerView.bounds.width - 32, height: 20)
        
        contentView.addSubview(headerView)
        
        // 创建基本信息卡片
        let infoCard = createInfoCard(frame: CGRect(
            x: 16,
            y: headerHeight + spacing,
            width: contentView.bounds.width - 32,
            height: infoCardHeight
        ))
        contentView.addSubview(infoCard)
        
        // 创建分析卡片
        let analysisCard = createAnalysisCard(frame: CGRect(
            x: 16,
            y: headerHeight + infoCardHeight + spacing * 2,
            width: contentView.bounds.width - 32,
            height: analysisCardHeight
        ))
        contentView.addSubview(analysisCard)
        
        // 创建图片
        let renderer = UIGraphicsImageRenderer(bounds: contentView.bounds)
        let image = renderer.image { context in
            contentView.layer.render(in: context.cgContext)
        }
        
        // 分享图片
        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = shareButton
        }
        
        present(activityVC, animated: true)
    }
    
    // 添加辅助方法来创建卡片
    private func createInfoCard(frame: CGRect) -> UIView {
        let cardView = UIView(frame: frame)
        cardView.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        cardView.layer.cornerRadius = 20
        
        let stackView = UIStackView(frame: CGRect(x: 24, y: 24, width: frame.width - 48, height: frame.height - 48))
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center
        
        let dateLabel = UILabel()
        dateLabel.text = formatDate(date)
        dateLabel.textColor = .lightGray
        dateLabel.font = .systemFont(ofSize: 14)
        
        let severityLabel = UILabel()
        severityLabel.text = severity
        severityLabel.font = .systemFont(ofSize: 28, weight: .bold)
        severityLabel.textColor = getSeverityColor(for: severity)
        
        let thresholdLabel = UILabel()
        thresholdLabel.text = String(format: NSLocalizedString("Average Hearing Loss: %.1f dB", comment: "Average hearing loss with value"), averageThreshold)
        thresholdLabel.textColor = .white
        thresholdLabel.font = .systemFont(ofSize: 16)
        
        [dateLabel, severityLabel, thresholdLabel].forEach { stackView.addArrangedSubview($0) }
        cardView.addSubview(stackView)
        
        return cardView
    }
    
    private func createAnalysisCard(frame: CGRect) -> UIView {
        let cardView = UIView(frame: frame)
        cardView.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        cardView.layer.cornerRadius = 20
        
        let titleLabel = UILabel(frame: CGRect(x: 24, y: 24, width: frame.width - 48, height: 24))
        titleLabel.text = NSLocalizedString("Professional Analysis", comment: "Title for professional analysis section")
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        
        let contentLabel = UILabel(frame: CGRect(x: 24, y: titleLabel.frame.maxY + 16, width: frame.width - 48, height: frame.height - 64))
        contentLabel.text = analysis
        contentLabel.textColor = .white
        contentLabel.font = .systemFont(ofSize: 16)
        contentLabel.numberOfLines = 0
        
        cardView.addSubview(titleLabel)
        cardView.addSubview(contentLabel)
        
        return cardView
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = NSLocalizedString("yyyy年MM月dd日 HH:mm", comment: "Date format")
        return formatter.string(from: date)
    }
    
    private func getSeverityColor(for severity: String) -> UIColor {
        switch severity {
        case NSLocalizedString("Normal", comment: "Normal hearing level"): return .systemGreen
        case NSLocalizedString("Mild Loss", comment: "Mild hearing loss"): return .systemYellow
        case NSLocalizedString("Moderate Loss", comment: "Moderate hearing loss"): return .systemOrange
        case NSLocalizedString("Severe Loss", comment: "Severe hearing loss"): return .systemRed
        case NSLocalizedString("Profound Loss", comment: "Profound hearing loss"): return .systemPurple
        default: return .systemGray
        }
    }
    
    private func createShareText() -> String {
        var shareText = NSLocalizedString("Hearing Analysis Report", comment: "Share title") + "\n\n"
        
        // 添加日期
        let formatter = DateFormatter()
        formatter.dateFormat = NSLocalizedString("yyyy年MM月dd日 HH:mm", comment: "Date format")
        shareText += NSLocalizedString("Test Time: ", comment: "Share test time label") + formatter.string(from: date) + "\n\n"
        
        // 添加听力等级和损失值
        shareText += NSLocalizedString("Hearing Level: ", comment: "Share hearing level label") + severity + "\n"
        shareText += String(format: NSLocalizedString("Average Hearing Loss: %.1f dB", comment: "Share average hearing loss"), averageThreshold) + "\n\n"
        
        // 添加专业分析
        shareText += NSLocalizedString("Professional Analysis:", comment: "Share analysis title") + "\n"
        shareText += analysis
        
        return shareText
    }
}

// MARK: - UITableViewDelegate & DataSource
extension HearingAnalysisViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        
        if indexPath.section == 0 {
            // 基本信息卡片
            let cardView = UIView()
            cardView.backgroundColor = UIColor.white.withAlphaComponent(0.15)
            cardView.layer.cornerRadius = 20
            
            let blurEffect = UIBlurEffect(style: .dark)
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.layer.cornerRadius = 20
            blurView.clipsToBounds = true
            
            let stackView = UIStackView()
            stackView.axis = .vertical
            stackView.spacing = 16
            stackView.alignment = .center
            
            let dateLabel = UILabel()
            dateLabel.text = formatDate(date)
            dateLabel.textColor = .lightGray
            dateLabel.font = .systemFont(ofSize: 14)
            
            let severityLabel = UILabel()
            severityLabel.text = severity
            severityLabel.font = .systemFont(ofSize: 28, weight: .bold)
            severityLabel.textColor = getSeverityColor(for: severity)
            
            let thresholdLabel = UILabel()
            thresholdLabel.text = String(format: NSLocalizedString("Average Hearing Loss: %.1f dB", comment: "Average hearing loss with value"), averageThreshold)
            thresholdLabel.textColor = .white
            thresholdLabel.font = .systemFont(ofSize: 16)
            
            chartImageView.image = chartImage
            
            [dateLabel, severityLabel, thresholdLabel, chartImageView].forEach { stackView.addArrangedSubview($0) }
            
            cell.contentView.addSubview(cardView)
            cardView.addSubview(blurView)
            cardView.addSubview(stackView)
            
            cardView.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
            }
            
            blurView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            stackView.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(24)
            }
            
            chartImageView.snp.makeConstraints { make in
                make.height.equalTo(200)
                make.width.equalTo(stackView.snp.width)
            }
            
            // 添加渐变边框
            let gradientLayer = CAGradientLayer()
            gradientLayer.colors = [
                UIColor.white.withAlphaComponent(0.5).cgColor,
                UIColor.white.withAlphaComponent(0.1).cgColor
            ]
            gradientLayer.startPoint = CGPoint(x: 0, y: 0)
            gradientLayer.endPoint = CGPoint(x: 1, y: 1)
            gradientLayer.frame = cardView.bounds
            gradientLayer.cornerRadius = 20
            
            let shapeLayer = CAShapeLayer()
            shapeLayer.lineWidth = 1
            shapeLayer.path = UIBezierPath(roundedRect: cardView.bounds, cornerRadius: 20).cgPath
            shapeLayer.fillColor = nil
            shapeLayer.strokeColor = UIColor.black.cgColor
            gradientLayer.mask = shapeLayer
            
            cardView.layer.addSublayer(gradientLayer)
            
        } else {
            // AI 分析卡片
            let cardView = UIView()
            cardView.backgroundColor = UIColor.white.withAlphaComponent(0.15)
            cardView.layer.cornerRadius = 20
            
            let blurEffect = UIBlurEffect(style: .dark)
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.layer.cornerRadius = 20
            blurView.clipsToBounds = true
            
            let titleLabel = UILabel()
            titleLabel.text = NSLocalizedString("Professional Analysis", comment: "Title for professional analysis section")
            titleLabel.textColor = .white
            titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
            
            let contentLabel = UILabel()
            contentLabel.text = analysis
            contentLabel.textColor = .white
            contentLabel.font = .systemFont(ofSize: 16)
            contentLabel.numberOfLines = 0
            
            cell.contentView.addSubview(cardView)
            cardView.addSubview(blurView)
            cardView.addSubview(titleLabel)
            cardView.addSubview(contentLabel)
            
            cardView.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
            }
            
            blurView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            titleLabel.snp.makeConstraints { make in
                make.top.leading.equalToSuperview().offset(24)
            }
            
            contentLabel.snp.makeConstraints { make in
                make.top.equalTo(titleLabel.snp.bottom).offset(16)
                make.leading.trailing.bottom.equalToSuperview().inset(24)
            }
            
            // 添加渐变边框
            let gradientLayer = CAGradientLayer()
            gradientLayer.colors = [
                UIColor.white.withAlphaComponent(0.5).cgColor,
                UIColor.white.withAlphaComponent(0.1).cgColor
            ]
            gradientLayer.startPoint = CGPoint(x: 0, y: 0)
            gradientLayer.endPoint = CGPoint(x: 1, y: 1)
            gradientLayer.frame = cardView.bounds
            gradientLayer.cornerRadius = 20
            
            let shapeLayer = CAShapeLayer()
            shapeLayer.lineWidth = 1
            shapeLayer.path = UIBezierPath(roundedRect: cardView.bounds, cornerRadius: 20).cgPath
            shapeLayer.fillColor = nil
            shapeLayer.strokeColor = UIColor.black.cgColor
            gradientLayer.mask = shapeLayer
            
            cardView.layer.addSublayer(gradientLayer)
        }
        
        return cell
    }
    
    // 移除 header 和 footer
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return section == 0 ? 0 : 16
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
}