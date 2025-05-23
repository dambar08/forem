# spec/requests/stories_index_spec.rb

require "rails_helper"

RSpec.describe "StoriesIndex" do
  it "redirects to the lowercase route", :aggregate_failures do
    get "/Bad_name"
    expect(response).to have_http_status(:moved_permanently)
    expect(response).to redirect_to("/bad_name")

    get "/Bad_name?i=i"
    expect(response).to have_http_status(:moved_permanently)
    expect(response).to redirect_to("/bad_name?i=i")
  end

  describe "GET stories index" do
    let(:user) { create(:user) }
    let(:org) { create(:organization) }

    it "redirects www to non-www if ENV var set" do
      allow(ApplicationConfig).to receive(:[]).with("REDIRECT_WWW_TO_ROOT").and_return("true")
      get "http://www.example.com/"
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to("http://example.com/")
    end

    it "does not redirect www to non-www if ENV var not set" do
      get "http://www.example.com/"
      expect(response).to have_http_status(:ok)
    end

    it "renders head content if present" do
      allow(Settings::UserExperience).to receive(:head_content).and_return("head content")
      get "/"
      expect(response.body).to include("head content")
    end

    it "redirects unfound subforem to root if ENV var set" do
      allow(ApplicationConfig).to receive(:[]).with("REDIRECT_WWW_TO_ROOT").and_return("true")
      allow(Subforem).to receive(:cached_id_by_domain).and_return(nil)
      allow(Subforem).to receive(:cached_root_domain).and_return("example.com")
      get "http://not-found.example.com"
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to("http://example.com/")
    end

    it "does not redirect found subforem to root if ENV var set" do
      ENV["REDIRECT_WWW_TO_ROOT"] = "true" # stubbing doesn't work properly here
      allow(Subforem).to receive(:cached_id_by_domain).and_return(1)
      allow(Subforem).to receive(:cached_root_domain).and_return("example.com")
      get "http://found.example.com"
      expect(response).to have_http_status(:ok)
      expect(response).not_to redirect_to("http://example.com/")
      ENV["REDIRECT_WWW_TO_ROOT"] = nil
    end

    it "renders topbar styles if Settings::UserExperience.accent_background_color_hex is set" do
      allow(Settings::UserExperience).to receive(:accent_background_color_hex).and_return("#000000")
      get "/"
      expect(response.body).to include("body:not(.dark-theme) #topbar {background")
    end

    it "does not render topbar styles if Settings::UserExperience.accent_background_color_hex is not set" do
      allow(Settings::UserExperience).to receive(:accent_background_color_hex).and_return(nil)
      get "/"
      expect(response.body).not_to include("body:not(.dark-theme) #topbar {background")
    end

    it "renders bottom of body content if present" do
      allow(Settings::UserExperience).to receive(:bottom_of_body_content).and_return("bottom of body content")
      get "/"
      expect(response.body).to include("bottom of body content")
    end

    it "renders page with article list and proper attributes", :aggregate_failures do
      article = create(:article, featured: true)
      navigation_link = create(:navigation_link)

      get "/"
      expect(response.body).to include(CGI.escapeHTML(article.title))
      renders_ga_tracking_fields
      renders_proper_description
      renders_min_read_time
      renders_proper_sidebar(navigation_link)
    end

    it "Does not render article with [Boost] as the title" do
      boost_article = create(:article, title: "[Boost]", score: 1000, featured: true, type_of: "status", body_markdown: "", main_image: "")
      non_boost_article = create(:article, title: "Not a boost article", score: 1000, featured: true)

      get "/"
      expect(response.body).not_to include(CGI.escapeHTML(boost_article.title))
      expect(response.body).to include(CGI.escapeHTML(non_boost_article.title))
    end

    it "doesn't render a featured scheduled article" do
      article = create(:article, featured: true, published_at: 1.hour.from_now)
      get "/"
      expect(response.body).not_to include(CGI.escapeHTML(article.title))
    end

    def renders_proper_description
      expect(response.body).to include(Settings::Community.community_description)
    end

    def renders_min_read_time
      expect(response.body).to include("min read")
    end

    def renders_proper_sidebar(navigation_link)
      expect(response.body).to include(CGI.escapeHTML(navigation_link.name))
    end

    def renders_ga_tracking_fields
      expect(response.body).to include("data-ga-tracking=\"#{Settings::General.ga_tracking_id}\"")
      expect(response.body).to include("data-ga4-tracking-id=\"#{Settings::General.ga_analytics_4_id}\"")
    end

    it "renders registration page if the Forem instance is private" do
      allow(Settings::UserExperience).to receive(:public).and_return(false)
      allow(Authentication::Providers).to receive(:enabled).and_return(%i[github twitter])

      get root_path
      expect(response.body).to include("Continue with GitHub")
      expect(response.body).to include("Continue with Twitter")
    end

    it "renders a landing page if one is active and if the site config is set to private" do
      allow(Settings::UserExperience).to receive(:public).and_return(false)
      create(:page, title: "This is a landing page!", landing_page: true)

      get root_path
      expect(response.body).to include("This is a landing page!")
    end

    it "renders billboards when published and approved for sidebar right (first position)" do
      ad = create(:billboard, published: true, approved: true, placement_area: "sidebar_right",
                              organization: org)

      get "/"
      expect(response.body).to include(ad.processed_html)
    end

    it "renders billboards when published and approved for sidebar right (second position)" do
      ad = create(:billboard, published: true, approved: true, placement_area: "sidebar_right_second",
                              organization: org)

      get "/"
      expect(response.body).to include(ad.processed_html)
    end

    it "renders billboards when published and approved for sidebar right (third position)" do
      ad = create(:billboard, published: true, approved: true, placement_area: "sidebar_right_third",
                              organization: org)

      get "/"
      expect(response.body).to include(ad.processed_html)
    end

    it "does not render billboards when not approved" do
      ad = create(:billboard, published: true, approved: false, placement_area: "sidebar_right",
                              organization: org)

      get "/"
      expect(response.body).not_to include(ad.processed_html)
    end

    it "renders only one billboard per placement" do
      billboard = create(:billboard, published: true, approved: true, placement_area: "sidebar_right",
                                     organization: org)
      second_billboard = create(:billboard, published: true, approved: true, placement_area: "sidebar_right",
                                            organization: org)

      get "/"
      expect(response.body).to include(billboard.processed_html).or(include(second_billboard.processed_html))
      expect(response.body).to include("crayons-card crayons-card--secondary crayons-bb").once
      expect(response.body).to include("sponsorship-dropdown-trigger-").once
    end

    it "renders a hero billboard" do
      allow(FeatureFlag).to receive(:enabled?).with(:hero_billboard).and_return(true)
      billboard = create(:billboard, published: true, approved: true, placement_area: "home_hero", organization: org)
      get "/"
      expect(response.body).to include(billboard.processed_html)
    end

    it "renders a footer billboard" do
      billboard = create(:billboard, published: true, approved: true, placement_area: "footer", organization: org)
      get "/"
      expect(response.body).to include(billboard.processed_html)
    end

    it "does not set cache-related headers if private" do
      allow(Settings::UserExperience).to receive(:public).and_return(false)
      get "/"
      expect(response).to have_http_status(:ok)

      expect(response.headers["X-Accel-Expires"]).to be_nil
      expect(response.headers["Cache-Control"]).not_to eq("public, no-cache")
      expect(response.headers["Surrogate-Key"]).to be_nil
    end

    it "renders social media handles if set" do
      allow(Settings::General).to receive(:social_media_handles)
        .and_return({ twitter: "twix", facebook: "fb", linkedin: "lnkdn", youtube: "whytube" })
      get "/"
      expect(response.body).to include("x.com/twix")
      expect(response.body).to include("facebook.com/fb")
      expect(response.body).to include("linkedin.com/in/lnkdn")
      expect(response.body).to include("youtube.com/@whytube")
    end

    it "sets correct cache headers", :aggregate_failures do
      get "/"

      expect(response).to have_http_status(:ok)
      sets_fastly_headers
      sets_nginx_headers
    end

    def sets_fastly_headers
      expected_surrogate_key_headers = %w[main_app_home_page]
      expect(response.headers["Surrogate-Key"].split(", ")).to match_array(expected_surrogate_key_headers)
    end

    def sets_nginx_headers
      expect(response.headers["X-Accel-Expires"]).to eq("600")
    end

    it "shows default meta keywords if set" do
      allow(Settings::General).to receive(:meta_keywords).and_return({ default: "cool developers, civil engineers" })
      get "/"
      expect(response.body).to include("<meta name=\"keywords\" content=\"cool developers, civil engineers\">")
    end

    it "does not show default meta keywords if not set" do
      allow(Settings::General).to receive(:meta_keywords).and_return({ default: "" })
      get "/"
      expect(response.body).not_to include(
        "<meta name=\"keywords\" content=\"cool developers, civil engineers\">",
      )
    end

    it "shows only one cover if basic feed style" do
      create_list(:article, 3, featured: true, score: 20, main_image: "https://example.com/image.jpg")

      allow(Settings::UserExperience).to receive(:feed_style).and_return("basic")
      get "/"
      expect(response.body.scan(/(?=class="crayons-article__cover crayons-article__cover__image__feed)/).count).to be 1
    end

    it "shows multiple cover images if rich feed style" do
      create_list(:article, 3, featured: true, score: 20, main_image: "https://example.com/image.jpg")

      allow(Settings::UserExperience).to receive(:feed_style).and_return("rich")
      get "/"
      # rubocop:disable Layout/LineLength
      expect(response.body.scan(/(?=class="crayons-article__cover crayons-article__cover__image__feed)/).count).to be > 1
      # rubocop:enable Layout/LineLength
    end

    context "with campaign hero" do
      let!(:hero_html) do
        create(
          :html_variant,
          group: "campaign",
          name: "hero",
          html: "<em>#{Faker::Book.title}'s</em>",
          published: true,
          approved: true,
        )
      end

      it "displays hero html when it exists and is set in config" do
        allow(Settings::Campaign).to receive(:hero_html_variant_name).and_return("hero")

        get root_path
        expect(response.body).to include(hero_html.html)
      end

      it "doesn't display when hero_html_variant_name is not set" do
        allow(Settings::Campaign).to receive(:hero_html_variant_name).and_return("")

        get root_path
        expect(response.body).not_to include(hero_html.html)
      end

      it "doesn't display when hero html is not approved" do
        allow(Settings::Campaign).to receive(:hero_html_variant_name).and_return("hero")
        hero_html.update_column(:approved, false)

        get root_path
        expect(response.body).not_to include(hero_html.html)
      end
    end

    context "with default_locale configured to fr" do
      before do
        allow(Settings::UserExperience).to receive(:default_locale).and_return("fr")
        get "/"
      end

      it "names proper locale" do
        expect(I18n.locale).to eq(:fr)
      end

      it "has proper locale content on page" do
        expect(response.body).to include("Recherche")
      end
    end
  end

  describe "GET stories index with timeframe" do
    describe "/latest" do
      let(:user) { create(:user) }
      let!(:low_score) { create(:article, score: Settings::UserExperience.home_feed_minimum_score - 50) }

      before do
        create_list(:article, 3, score: Settings::UserExperience.home_feed_minimum_score + 1)
      end

      it "includes a link to Relevant", :aggregate_failures do
        get "/latest"

        expected_tag = "<a data-text=\"Relevant\" href=\"/\""
        expect(response.body).to include(expected_tag)
      end

      it "includes message and a link to sign in for signed-out" do
        get "/latest"
        expect(response.body).to include("Some latest posts are only visible for members")
        expect(response.body).to match(/Sign in.*to see all latest/)
      end

      it "excludes low-score content for signed-out" do
        get "/latest"
        expect(response.body).not_to include(low_score.title)
      end
    end

    describe "/top/week" do
      it "includes a link to Relevant", :aggregate_failures do
        get "/top/week"

        expected_tag = "<a data-text=\"Relevant\" href=\"/\""
        expect(response.body).to include(expected_tag)
      end
    end
  end

  describe "GET locale index" do
    it "names proper locale" do
      get "/locale/fr"
      expect(I18n.locale).to eq(:fr)
    end

    it "has proper locale content on page" do
      get "/locale/fr"
      expect(response.body).to include("Recherche")
    end

    it "uses fallback locale if invalid locale passed" do
      get "/locale/fake"
      expect(I18n.locale).to eq(:en)
    end
  end

  describe "GET podcast index" do
    it "renders page with proper header" do
      podcast = create(:podcast)
      create(:podcast_episode, podcast: podcast)
      get "/#{podcast.slug}"
      expect(response.body).to include(podcast.title)
    end
  end

  describe "Middleware: SetSubforem" do
    context "when passed_domain param is provided" do
      it "calls Subforem.cached_id_by_domain with the passed domain" do
        allow(Subforem).to receive(:cached_id_by_domain).and_call_original
        allow(Subforem).to receive(:cached_default_id).and_return(999)
        get "/", params: { passed_domain: "sub.mysite.com" }
        # This ensures that the subforem logic tries to use "sub.mysite.com"
        expect(Subforem).to have_received(:cached_id_by_domain).with("sub.mysite.com")
      end
    end

    context "when host is a subdomain" do
      it "removes session and remember_user_token cookies from the response" do
        # Make sure you have an ApplicationConfig["SESSION_KEY"] defined
        # in your test environment
        # allow(ApplicationConfig).to receive(:[]).with("SESSION_KEY").and_return("_session_key")

        get "/", headers: { "Host" => "sub.example.com" }

        # "Set-Cookie" won't exist if the middleware has deleted it
        # or you might see a blank or partial string. Let's just confirm it's not present:
        expect(response.headers["Set-Cookie"].to_s).not_to include(ENV["SESSION_KEY"])
        expect(response.headers["Set-Cookie"].to_s).not_to include("remember_user_token")
      end
    end
  end
end
