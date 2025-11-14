//
//  BeforeAfterSlider.swift
//  Ugly Homes
//
//  Before/After Photo Slider Component
//

import SwiftUI

struct BeforeAfterSlider: View {
    let beforeImageUrl: String
    let afterImageUrl: String

    @State private var sliderPosition: CGFloat = 0.0
    @GestureState private var dragOffset: CGFloat = 0
    @State private var hasAppeared: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // After image (background)
                AsyncImage(url: URL(string: afterImageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(ProgressView())
                }

                // Before image (masked/clipped)
                AsyncImage(url: URL(string: beforeImageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .mask(
                            Rectangle()
                                .frame(width: geometry.size.width * sliderPosition)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        )
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(ProgressView())
                        .mask(
                            Rectangle()
                                .frame(width: geometry.size.width * sliderPosition)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        )
                }

                // Slider handle/divider
                VStack {
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 4, height: geometry.size.height)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 0)

                    // Drag handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 50, height: 50)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        .overlay(
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .bold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.gray)
                        )
                        .offset(y: -25)
                }
                .position(x: geometry.size.width * sliderPosition, y: geometry.size.height / 2)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: sliderPosition)

                // Labels
                HStack {
                    // BEFORE label
                    Text("BEFORE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                        )
                        .padding(12)
                        .opacity(hasAppeared ? 1.0 : 0.0)
                        .animation(.easeIn(duration: 0.5).delay(0.2), value: hasAppeared)

                    Spacer()

                    // AFTER label
                    Text("AFTER")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                        )
                        .padding(12)
                        .opacity(hasAppeared ? 1.0 : 0.0)
                        .animation(.easeIn(duration: 0.5).delay(0.2), value: hasAppeared)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newPosition = value.location.x / geometry.size.width
                        sliderPosition = min(max(newPosition, 0), 1)
                    }
            )
            .onAppear {
                // Initial reveal animation - slide from right to left
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.3)) {
                    sliderPosition = 0.5
                }
                hasAppeared = true
            }
        }
    }
}

#Preview {
    BeforeAfterSlider(
        beforeImageUrl: "https://example.com/before.jpg",
        afterImageUrl: "https://example.com/after.jpg"
    )
    .frame(height: 400)
}
