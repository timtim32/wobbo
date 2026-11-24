# Spec Delta

## MODIFIED Requirements

### Requirement: On-screen size and sharpness
The character SHALL be about 110 points tall at its default scale, and SHALL support the chosen heights of about 80, 110, 140 and 170 points, so that it and a speech balloon above it fit within the overlay strip. It SHALL look sharp, without blurry or jagged edges or coloured fringes, on both Retina and non-Retina displays and on the transparent overlay, at each of these heights.

#### Scenario: Retina display
- **WHEN** the character is shown on a Retina display at its default scale
- **THEN** its edges are sharp and smooth, with no visible pixels or halos against the desktop behind it

#### Scenario: Fits the strip
- **WHEN** the character stands at the bottom of the overlay strip
- **THEN** it is fully visible and leaves room above it for a speech balloon

#### Scenario: Largest size
- **WHEN** the character is shown at about 170 points tall on a Retina and on a non-Retina display
- **THEN** it is sharp on both, fully visible in the strip, and still leaves room above it for a speech balloon
