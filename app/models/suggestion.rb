require 'pry-byebug'

class Suggestion < ApplicationRecord
  WEIGHTS = {
    des_p_types: 1,
    des_partnerships: 2,
    click_count: 3,
    customer_interests: 2,
    des_partner_competitor: 1,
    acq_partner_competitor: 3
  }

  # rating.each * (weight.values.each / weight.values.inject(&:+))

  attr_writer :weights

  belongs_to :business
  belongs_to :suggested_business, class_name: 'Business'

  before_create :calculate_rating

  default_scope { order(rating: :desc) }

  def weights
    @weights || WEIGHTS
  end

  def calculate_rating
    des_p_types_rating            = 0
    des_partnerships_rating       = 0
    click_count_rating            = 0
    customer_interests_rating     = 0
    des_partner_competitor_rating = 0
    acq_partner_competitor_rating = 0

    # Calculating against desired business partnership type match
    des_p_types_rating += (suggested_business.offered_partnership_types & business.desired_partnership_types).count
    des_p_types_rating /= business.desired_partnership_types.count.to_f

    # Check if they are on each others partnerships desired list
    if (
      business.partnerships.desired.map(&:partner_id).include?(suggested_business.id) & suggested_business.partnerships.desired.map(&:partner_id).include?(business.id)
      )
      des_partnerships_rating = 1.0
    end

    # Calculate based on clicks for each other
    clicked_on_suggested = business.clicks.where(clicked: suggested_business).first_or_create.count
    clicked_by_suggested = suggested_business.clicks.where(clicked: business).first_or_create.count
    click_pair = [clicked_on_suggested, clicked_by_suggested]

    if click_pair[0] < 3 || click_pair[1] < 3
      click_count_rating = 0.0
    elsif click_pair[0] >= 10 || click_pair[1] >= 10
      click_count_rating = 1.0
    else
      # See other potential algorithm checks in 'lib/tasks/count_rating_test.rake'
      click_count_rating = ((click_pair.sum) / (click_pair.max * 2).to_f * click_pair.min / 10)
    end

    # Check if their customer interests align
    customer_interests_rating = (business.customer_interests & suggested_business.customer_interests).count
    customer_interests_rating /= business.customer_interests.count.to_f

    # Check if suggested business is a competitor to desired partners
    des_partner_competitor_rating = (business.partnerships.desired.map(&:partner_id) & suggested_business.competitors.map(&:id)).count
    des_partner_competitor_rating /= business.partnerships.desired.count.to_f

    # Check if suggested business is a competitor to acquired partners
    acq_partner_competitor_rating = (business.partnerships.acquired.map(&:partner_id) & suggested_business.competitors.map(&:id)).count
    acq_partner_competitor_rating /= business.partnerships.acquired.count.to_f

    # insert variable weighting multipliers for each rating based on user preferences
    # Use self#weights

    total_rating = [
      des_p_types_rating,
      des_partnerships_rating,
      click_count_rating,
      customer_interests_rating,
      des_partner_competitor_rating,
      acq_partner_competitor_rating
    ]

    weighted_ratings = total_rating.each_with_index.inject([]) do |res, (rating, index)|
      res << weights.values[index] * rating
    end

    final_rating = (weighted_ratings.sum * 100 / weights.values.sum.to_f).to_i

    p final_rating
    self.rating = final_rating
  end
end
