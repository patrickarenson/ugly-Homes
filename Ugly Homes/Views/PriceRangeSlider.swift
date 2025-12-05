//
//  PriceRangeSlider.swift
//  Ugly Homes
//
//  Logarithmic dual-handle price range slider
//

import SwiftUI

struct PriceRangeSlider: View {
    @Binding var minPrice: Double
    @Binding var maxPrice: Double

    // Price range bounds (logarithmic scale works better for real estate)
    let absoluteMin: Double = 25000      // $25K
    let absoluteMax: Double = 50000000   // $50M

    @State private var minPosition: CGFloat = 0
    @State private var maxPosition: CGFloat = 1

    var body: some View {
        VStack(spacing: 12) {
            // Price labels
            HStack {
                Text(formatPrice(minPrice))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Text(formatPrice(maxPrice))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }

            // Slider track
            GeometryReader { geometry in
                let trackWidth = geometry.size.width

                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)

                    // Selected range highlight
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(width: max(0, (maxPosition - minPosition) * trackWidth), height: 6)
                        .offset(x: minPosition * trackWidth)

                    // Min handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 2)
                        )
                        .offset(x: minPosition * trackWidth - 12)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newPosition = max(0, min(value.location.x / trackWidth, maxPosition - 0.05))
                                    minPosition = newPosition
                                    minPrice = positionToPrice(newPosition)
                                }
                        )

                    // Max handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 2)
                        )
                        .offset(x: maxPosition * trackWidth - 12)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newPosition = max(minPosition + 0.05, min(value.location.x / trackWidth, 1))
                                    maxPosition = newPosition
                                    maxPrice = positionToPrice(newPosition)
                                }
                        )
                }
            }
            .frame(height: 24)
        }
        .onAppear {
            // Initialize positions from prices
            minPosition = priceToPosition(minPrice)
            maxPosition = priceToPosition(maxPrice)
        }
    }

    // Convert price to slider position (0-1) using logarithmic scale
    func priceToPosition(_ price: Double) -> CGFloat {
        let logMin = log10(absoluteMin)
        let logMax = log10(absoluteMax)
        let logPrice = log10(max(absoluteMin, min(absoluteMax, price)))
        return CGFloat((logPrice - logMin) / (logMax - logMin))
    }

    // Convert slider position (0-1) to price using logarithmic scale
    func positionToPrice(_ position: CGFloat) -> Double {
        let logMin = log10(absoluteMin)
        let logMax = log10(absoluteMax)
        let logPrice = logMin + Double(position) * (logMax - logMin)
        let rawPrice = pow(10, logPrice)

        // Round to nice increments based on price range
        if rawPrice < 100000 {
            return round(rawPrice / 5000) * 5000  // $5K increments
        } else if rawPrice < 500000 {
            return round(rawPrice / 10000) * 10000  // $10K increments
        } else if rawPrice < 1000000 {
            return round(rawPrice / 25000) * 25000  // $25K increments
        } else if rawPrice < 5000000 {
            return round(rawPrice / 100000) * 100000  // $100K increments
        } else {
            return round(rawPrice / 500000) * 500000  // $500K increments
        }
    }

    func formatPrice(_ price: Double) -> String {
        if price >= 1000000 {
            let millions = price / 1000000
            if millions == floor(millions) {
                return "$\(Int(millions))M"
            } else {
                return String(format: "$%.1fM", millions)
            }
        } else if price >= 1000 {
            return "$\(Int(price / 1000))K"
        } else {
            return "$\(Int(price))"
        }
    }
}

#Preview {
    VStack {
        PriceRangeSlider(
            minPrice: .constant(100000),
            maxPrice: .constant(500000)
        )
        .padding()
    }
}
