//
//  ContentView.swift
//  RefreshableTableView
//
//  Created by Cydiater on 29/7/2024.
//

import SwiftUI
import UIKit

public struct MyActivityIndicator: ProgressViewStyle {
    @State private var isRotating = 0.0
    
    public func makeBody(configuration: ProgressViewStyleConfiguration) -> some View {
        VStack {
            ZStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24)
                    .rotationEffect(.degrees(isRotating))
            }
        }
        .frame(width: 60, height: 60)
        .onAppear {
            withAnimation(.linear(duration: 0.5)
                .repeatForever(autoreverses: false)) {
                    isRotating = 360.0
                }
        }
    }
}

struct IndicatorView: View {
    @ObservedObject var i_: MyUITableViewController.Internal
    
    var body: some View {
        HStack {
            Spacer()
            ZStack {
                ProgressView()
                    .progressViewStyle(MyActivityIndicator())
                    .opacity(i_.viewRefreshing ? 1 : 0)
                Image(systemName: "arrow.down")
                    .opacity(i_.viewRefreshing ? 0 : 1)
            }
            Spacer()
        }
        .frame(height: 40)
    }
}


class MyUITableViewController: UIViewController, UITableViewDelegate {
    let tableView: UITableView
    let dataSource: UITableViewDiffableDataSource<Int, Int>
    var refreshIntentionReleased = false
    
    var didTriggerRefreshIntention: () -> ()
    
    class Internal: ObservableObject {
        @Published var viewRefreshing = false
    }
    
    let i_: Internal
    
    static let triggerRefreshIntentionThreshold: Double = 40
    
    init(didTriggerRefreshIntention: @escaping () -> ()) {
        let tableView = UITableView()
        let i_ = Internal()
        let dataSource = UITableViewDiffableDataSource<Int, Int>(tableView: tableView, cellProvider: { tableView, indexPath, item in
            if item == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "refresh-indicator", for: indexPath)
                cell.contentConfiguration = UIHostingConfiguration {
                    IndicatorView(i_: i_)
                }
                .background(.clear)
                .margins(.all, 0)
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "swiftui-hosting", for: indexPath)
                cell.selectionStyle = .none
                cell.contentConfiguration = UIHostingConfiguration {
                    let idx = item
                    HStack {
                        Text(idx.description)
                            .padding(.horizontal)
                        Spacer()
                        Text("1")
                            .padding(.horizontal)
                            .italic()
                    }
                    .font(.title)
                    .border(.black)
                    .background(.blue)
                    .padding(.horizontal)
                    .padding(.vertical, 3)
                }
                .margins(.all, 0)
                return cell
            }
        })
        
        self.i_ = i_
        self.tableView = tableView
        self.dataSource = dataSource
        self.didTriggerRefreshIntention = didTriggerRefreshIntention
        
        super.init(nibName: nil, bundle: nil)
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "swiftui-hosting")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "refresh-indicator")
        
        tableView.delegate = self
        tableView.dataSource = dataSource
        tableView.separatorStyle = .none
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(tableView)
        
        var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        snapshot.appendSections([0])
        snapshot.appendItems(Array(0..<2000))
        dataSource.apply(snapshot)
        
        tableView.contentInset.top = -MyUITableViewController.triggerRefreshIntentionThreshold
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        tableView.frame = view.frame
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.isTracking &&
            scrollView.contentOffset.y + scrollView.adjustedContentInset.top < -MyUITableViewController.triggerRefreshIntentionThreshold &&
            !refreshIntentionReleased &&
            !i_.viewRefreshing
        {
            refreshIntentionReleased = true
            didTriggerRefreshIntention()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        refreshIntentionReleased = false
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if i_.viewRefreshing {
            scrollView.contentInset.top = 0
        }
    }
    
    func animateRefreshFinished() {
        guard i_.viewRefreshing else { return }
        DispatchQueue.main.schedule {
            self.i_.viewRefreshing = false
        }
        UIView.animate(withDuration: 0.3, delay: 0, options: [.allowUserInteraction]) {
            self.tableView.contentInset.top = -MyUITableViewController.triggerRefreshIntentionThreshold
        }
    }
    
    func setViewRefreshed() {
        guard !i_.viewRefreshing else { return }
        DispatchQueue.main.schedule {
            self.i_.viewRefreshing = true
        }
        if !tableView.isTracking {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.allowUserInteraction]) {
                self.tableView.contentOffset.y = -self.tableView.adjustedContentInset.top - MyUITableViewController.triggerRefreshIntentionThreshold
                self.tableView.contentInset.top = 0
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct MyTableView: UIViewControllerRepresentable {
    typealias UIViewControllerType = MyUITableViewController
    
    @Binding var viewRefreshing: Bool
    
    init(viewRefreshing: Binding<Bool>) {
        self._viewRefreshing = viewRefreshing
    }
    
    func makeUIViewController(context: Context) -> UIViewControllerType {
        let viewController = MyUITableViewController(didTriggerRefreshIntention: {
            viewRefreshing = true
            Task {
                try! await Task.sleep(nanoseconds: 3_000_000_000)
                viewRefreshing = false
            }
        })
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        if viewRefreshing && !uiViewController.i_.viewRefreshing {
            uiViewController.setViewRefreshed()
        } else if !viewRefreshing && uiViewController.i_.viewRefreshing {
            uiViewController.animateRefreshFinished()
        }
    }
}

struct ContentView: View {
    @State private var viewRefreshing = false

    var body: some View {
        NavigationStack {
            MyTableView(viewRefreshing: $viewRefreshing)
                .ignoresSafeArea()
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                .navigationTitle("Demo")
                .toolbar {
                    Toggle(isOn: $viewRefreshing, label: {
                        Text("Refresh")
                    })
                }
        }
    }
}

#Preview {
    ContentView()
}
