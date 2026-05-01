require 'scraperwiki'
require 'mechanize'
require 'nokogiri'

# =============================================================================
# SA Local Government Councillors Scraper
# morph.io scraper — outputs one row per elected member across all 68 SA councils
#
# Schema: name, role, ward, council, email, phone, url, source_url
#
# Council list source: Electoral Commission SA
# https://www.ecsa.sa.gov.au/elections/council-supplementary-list/council-fast-facts?view=article&id=102:council-links
# =============================================================================

# =============================================================================
# COUNCIL INDEX
# Each entry maps to a scrape_* function below.
# members_url: direct URL of the elected members page (confirmed or best-guess)
# scraper: symbol of the function to call
#
# Status guide:
#   :opencities  — Granicus/OpenCities CMS, scraper confirmed against live HTML
#   :pae         — Port Adelaide Enfield custom CMS
#   :todo        — not yet implemented, will log and skip
# =============================================================================
COUNCILS = [

  # --- OpenCities (Granicus) CMS ---
  # Confirmed via live HTML fetch of westtorrens.sa.gov.au.
  # Structure: h2 > a (person) interleaved with bare h2 (ward heading),
  # contact details in li elements below each person h2.
  { name: "City of West Torrens",                      scraper: :opencities, members_url: "https://www.westtorrens.sa.gov.au/Council/Your-Council/Elected-Members" },
  { name: "City of Salisbury",                         scraper: :opencities, members_url: "https://www.salisbury.sa.gov.au/council/elected-members-and-wards" },
  { name: "Campbelltown City Council",                 scraper: :opencities, members_url: "https://www.campbelltown.sa.gov.au/council/elected-members-and-staff/elected-members" },
  { name: "City of Charles Sturt",                     scraper: :opencities, members_url: "https://www.charlessturt.sa.gov.au/council/role-of-council/our-council/councillorcontacts" },
  { name: "City of Marion",                            scraper: :opencities, members_url: "https://www.marion.sa.gov.au/about-council/elected-members" },
  { name: "City of Mitcham",                           scraper: :opencities, members_url: "https://www.mitchamcouncil.sa.gov.au/Council/Your-Council/Elected-Members" },
  { name: "City of Norwood Payneham & St Peters",      scraper: :opencities, members_url: "https://www.npsp.sa.gov.au/council/elected-members" },
  { name: "City of Onkaparinga",                       scraper: :opencities, members_url: "https://www.onkaparingacity.com/Council/Your-Council/Elected-Members" },
  { name: "City of Playford",                          scraper: :opencities, members_url: "https://www.playford.sa.gov.au/Council/Your-Council/Elected-Members" },
  { name: "City of Prospect",                          scraper: :opencities, members_url: "https://www.prospect.sa.gov.au/council/elected-members" },
  { name: "City of Tea Tree Gully",                    scraper: :opencities, members_url: "https://www.teatreegully.sa.gov.au/Council/Your-Council/Elected-Members" },
  { name: "City of Burnside",                          scraper: :opencities, members_url: "https://www.burnside.sa.gov.au/council/elected-members" },
  { name: "City of Holdfast Bay",                      scraper: :opencities, members_url: "https://www.holdfast.sa.gov.au/council/wards" },
  { name: "Adelaide Hills Council",                    scraper: :opencities, members_url: "https://www.ahc.sa.gov.au/council/elected-members" },
  { name: "Mount Barker District Council",             scraper: :opencities, members_url: "https://www.mountbarker.sa.gov.au/council/elected-members" },
  { name: "Town of Gawler",                            scraper: :opencities, members_url: "https://www.gawler.sa.gov.au/council/elected-members" },
  { name: "Light Regional Council",                    scraper: :opencities, members_url: "https://www.light.sa.gov.au/council/elected-members" },
  { name: "Adelaide Plains Council",                   scraper: :opencities, members_url: "https://www.mallala.sa.gov.au/council/elected-members" },
  { name: "Alexandrina Council",                       scraper: :opencities, members_url: "https://www.alexandrina.sa.gov.au/council/elected-members" },
  { name: "Kangaroo Island Council",                   scraper: :opencities, members_url: "https://www.kangarooisland.sa.gov.au/council/about/elected-members" },
  { name: "City of Victor Harbor",                     scraper: :opencities, members_url: "https://www.victor.sa.gov.au/council/elected-members" },
  { name: "Wakefield Regional Council",                scraper: :opencities, members_url: "https://www.wrc.sa.gov.au/council/elected-members" },

  # --- Port Adelaide Enfield ---
  { name: "City of Port Adelaide Enfield",             scraper: :pae,        members_url: "https://www.cityofpae.sa.gov.au/meet-your-elected-members" },

  # --- TODO: remaining 45 councils ---
  { name: "City of Adelaide",                          scraper: :todo,       members_url: "https://www.cityofadelaide.com.au/about-council/your-council/council-members/" },
  { name: "The Barossa Council",                       scraper: :todo,       members_url: "https://www.barossa.sa.gov.au/council/elected-members" },
  { name: "Barunga West Council",                      scraper: :todo,       members_url: "https://www.barungawest.sa.gov.au/council/elected-members" },
  { name: "Berri Barmera Council",                     scraper: :todo,       members_url: "https://www.berribarmera.sa.gov.au/council/elected-members" },
  { name: "The District Council of Ceduna",            scraper: :todo,       members_url: "https://www.ceduna.sa.gov.au/council/elected-members" },
  { name: "Clare & Gilbert Valleys Council",           scraper: :todo,       members_url: "https://www.claregilbertvalleys.sa.gov.au/council/elected-members" },
  { name: "District Council of Cleve",                 scraper: :todo,       members_url: "https://www.cleve.sa.gov.au/council/elected-members" },
  { name: "District Council of Coober Pedy",           scraper: :todo,       members_url: "https://www.cooberpedy.sa.gov.au/council/elected-members" },
  { name: "Coorong District Council",                  scraper: :todo,       members_url: "https://www.coorong.sa.gov.au/council/elected-members" },
  { name: "Copper Coast Council",                      scraper: :todo,       members_url: "https://www.coppercoast.sa.gov.au/council/elected-members" },
  { name: "District Council of Elliston",              scraper: :todo,       members_url: "https://www.elliston.sa.gov.au/council/elected-members" },
  { name: "The Flinders Ranges Council",               scraper: :todo,       members_url: "https://www.frc.sa.gov.au/council/elected-members" },
  { name: "District Council of Franklin Harbour",      scraper: :todo,       members_url: "https://www.franklinharbour.sa.gov.au/council/elected-members" },
  { name: "Regional Council of Goyder",                scraper: :todo,       members_url: "https://www.goyder.sa.gov.au/council/elected-members" },
  { name: "District Council of Grant",                 scraper: :todo,       members_url: "https://www.dcgrant.sa.gov.au/council/elected-members" },
  { name: "District Council of Karoonda East Murray",  scraper: :todo,       members_url: "https://www.dckem.sa.gov.au/council/elected-members" },
  { name: "District Council of Kimba",                 scraper: :todo,       members_url: "https://www.kimba.sa.gov.au/council/elected-members" },
  { name: "Kingston District Council",                 scraper: :todo,       members_url: "https://www.kingstondc.sa.gov.au/council/elected-members" },
  { name: "District Council of Lower Eyre Peninsula",  scraper: :todo,       members_url: "https://www.lowereyrepeninsula.sa.gov.au/council/elected-members" },
  { name: "District Council of Loxton Waikerie",       scraper: :todo,       members_url: "https://www.loxtonwaikerie.sa.gov.au/council/elected-members" },
  { name: "Mid Murray Council",                        scraper: :todo,       members_url: "https://www.mid-murray.sa.gov.au/council/elected-members" },
  { name: "City of Mount Gambier",                     scraper: :todo,       members_url: "https://www.mountgambier.sa.gov.au/council/elected-members" },
  { name: "District Council of Mount Remarkable",      scraper: :todo,       members_url: "https://www.mtr.sa.gov.au/council/elected-members" },
  { name: "The Rural City of Murray Bridge",           scraper: :todo,       members_url: "https://www.murraybridge.sa.gov.au/council/elected-members" },
  { name: "Naracoorte Lucindale Council",              scraper: :todo,       members_url: "https://www.naracoortelucindale.sa.gov.au/council/elected-members" },
  { name: "Northern Areas Council",                    scraper: :todo,       members_url: "https://www.nacouncil.sa.gov.au/council/elected-members" },
  { name: "District Council of Orroroo Carrieton",     scraper: :todo,       members_url: "https://www.orroroo.sa.gov.au/council/elected-members" },
  { name: "District Council of Peterborough",          scraper: :todo,       members_url: "https://www.peterborough.sa.gov.au/council/elected-members" },
  { name: "Port Augusta City Council",                 scraper: :todo,       members_url: "https://www.portaugusta.sa.gov.au/council/elected-members" },
  { name: "City of Port Lincoln",                      scraper: :todo,       members_url: "https://www.portlincoln.sa.gov.au/council/elected-members" },
  { name: "Port Pirie Regional Council",               scraper: :todo,       members_url: "https://www.pirie.sa.gov.au/council/elected-members" },
  { name: "Renmark Paringa Council",                   scraper: :todo,       members_url: "https://www.renmarkparinga.sa.gov.au/council/elected-members" },
  { name: "District Council of Robe",                  scraper: :todo,       members_url: "https://www.robe.sa.gov.au/council" },
  { name: "Municipal Council of Roxby Downs",          scraper: :todo,       members_url: "https://www.roxbydowns.com/council/elected-members" },
  { name: "Southern Mallee District Council",          scraper: :todo,       members_url: "https://www.southernmallee.sa.gov.au/council/elected-members" },
  { name: "District Council of Streaky Bay",           scraper: :todo,       members_url: "https://www.streakybay.sa.gov.au/council/elected-members" },
  { name: "Tatiara District Council",                  scraper: :todo,       members_url: "https://www.tatiara.sa.gov.au/council/elected-members" },
  { name: "District Council of Tumby Bay",             scraper: :todo,       members_url: "https://www.tumbybay.sa.gov.au/council/elected-members" },
  { name: "The City of Unley",                         scraper: :todo,       members_url: "https://www.unley.sa.gov.au/council/elected-members" },
  { name: "Corporation of the Town of Walkerville",    scraper: :todo,       members_url: "https://www.walkerville.sa.gov.au/council/elected-members" },
  { name: "Wattle Range Council",                      scraper: :todo,       members_url: "https://www.wattlerange.sa.gov.au/council/elected-members" },
  { name: "City of Whyalla",                           scraper: :todo,       members_url: "https://www.whyalla.sa.gov.au/council/elected-members" },
  { name: "Wudinna District Council",                  scraper: :todo,       members_url: "https://www.wudinna.sa.gov.au/council/elected-members" },
  { name: "District Council of Yankalilla",            scraper: :todo,       members_url: "https://www.yankalilla.sa.gov.au/council/elected-members" },
  { name: "Yorke Peninsula Council",                   scraper: :todo,       members_url: "https://www.yorke.sa.gov.au/council/elected-members" },
].freeze

# =============================================================================
# SHARED HELPERS
# =============================================================================

def make_agent
  agent = Mechanize.new
  agent.user_agent_alias = 'Mac Safari'
  agent.open_timeout = 15
  agent.read_timeout = 20
  agent.redirect_ok = true
  agent
end

# Fetch a page, return nil and log on failure rather than crashing the whole run
def fetch_page(agent, url, council_name)
  sleep 1  # be polite — 1 second between requests
  agent.get(url)
rescue => e
  puts "  ERROR fetching #{url}: #{e.message}"
  nil
end

# Extract the first email address from a string
def extract_email(text)
  return nil if text.nil? || text.empty?
  text.match(/[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}/i)&.to_s
end

# Normalise phone — returns nil if nothing digit-like found
def clean_phone(text)
  return nil if text.nil?
  stripped = text.gsub(/[^\d\s+()]/, '').strip
  return nil if stripped.gsub(/\D/, '').length < 8
  text.strip.gsub(/\s+/, ' ')
end

# Derive role from a heading string
def extract_role(title_text)
  t = title_text.to_s.strip
  if t.match?(/deputy\s+mayor/i)
    "Deputy Mayor"
  elsif t.match?(/\bmayor\b/i)
    "Mayor"
  elsif t.match?(/deputy\s+chairperson/i)
    "Deputy Chairperson"
  elsif t.match?(/\bchairperson\b/i)
    "Chairperson"
  else
    "Councillor"
  end
end

# Strip role prefix from a name string
def clean_name(raw)
  raw.to_s.strip
    .sub(/\A(Deputy\s+Mayor,?\s*|Mayor\s*|Councillor\s*|Cr\.?\s*|Deputy\s+Chairperson,?\s*|Chairperson\s*)/i, '')
    .strip
end

# Save one record — unique key is council + name
def save_record(record)
  puts "  #{record['role']}: #{record['name']} | ward: #{record['ward'] || '—'} | #{record['email'] || 'no email'}"
  ScraperWiki.save_sqlite(['council', 'name'], record)
end

# =============================================================================
# OPENCITIES (GRANICUS) SCRAPER
#
# Confirmed structure (westtorrens.sa.gov.au, fetched 2026-05-01):
#
#   <h2><a href="/path/to/Mayor-Name">Mayor Michael Coxon</a></h2>
#   <ul>
#     <li>Telephone0402 212 002</li>
#     <li>Email <a href="mailto:mayor@council.sa.gov.au">mayor@...</a></li>
#   </ul>
#   <h2>Hilton ward</h2>          ← bare h2, no <a> = ward heading
#   <h2><a href="...">Councillor Jane Smith</a></h2>
#   ...
#
# Strategy: walk all h2s in document order, tracking current_ward.
# For each person h2, collect sibling nodes until the next h2 for contact details.
# =============================================================================
def scrape_opencities(agent, council)
  puts "\n[#{council[:name]}] OpenCities"
  page = fetch_page(agent, council[:members_url], council[:name])
  return unless page

  doc = page.parser
  current_ward = nil
  found = 0

  doc.css('h2').each do |h2|
    link = h2.at_css('a[href]')

    if link.nil?
      # Bare h2 = ward heading
      text = h2.text.strip
      current_ward = text unless text.empty?
      next
    end

    full_title = link.text.strip
    next if full_title.empty?

    role = extract_role(full_title)
    name = clean_name(full_title)
    next if name.empty?

    # Build profile URL
    href = link['href'].to_s
    profile_url = if href.start_with?('http')
      href
    else
      begin
        URI.join(council[:members_url], href).to_s
      rescue
        href
      end
    end

    # Collect sibling nodes between this h2 and the next h2
    section_nodes = []
    node = h2.next_sibling
    while node && !(node.element? && node.name == 'h2')
      section_nodes << node
      node = node.next_sibling
    end
    section_doc = Nokogiri::HTML::DocumentFragment.parse(section_nodes.map(&:to_s).join)

    # Email: prefer mailto href in section, fall back to regex
    mailto_link = section_doc.at_css("a[href^='mailto:']")
    email = if mailto_link
      mailto_link['href'].sub(/\Amailto:/i, '').split('?').first.strip
    else
      extract_email(section_doc.text)
    end

    # Phone: look for li containing "Telephone" or a phone-pattern number
    phone = nil
    section_doc.css('li').each do |li|
      text = li.text.strip
      if text.match?(/telephone/i)
        phone = clean_phone(text.sub(/\Atelephone\s*/i, ''))
        break
      end
    end
    if phone.nil?
      phone_match = section_doc.text.match(/(\(08\)\s*\d{4}\s*\d{4}|04\d{2}\s*[\d\s]{7,9})/)
      phone = clean_phone(phone_match[0]) if phone_match
    end

    ward = (role == "Mayor") ? nil : current_ward

    save_record({
      'name'       => name,
      'role'       => role,
      'ward'       => ward,
      'council'    => council[:name],
      'email'      => email,
      'phone'      => phone,
      'url'        => profile_url,
      'source_url' => council[:members_url],
    })
    found += 1
  end

  puts "  → #{found} members saved" if found > 0
  puts "  WARN: 0 members found — selector may need updating" if found == 0
end

# =============================================================================
# PORT ADELAIDE ENFIELD SCRAPER
#
# PAE uses a card-based layout. We try a set of likely card selectors and fall
# back to an email-domain scan if none match, logging clearly either way.
# members_url: https://www.cityofpae.sa.gov.au/meet-your-elected-members
# =============================================================================
def scrape_pae(agent, council)
  puts "\n[#{council[:name]}] PAE custom"
  page = fetch_page(agent, council[:members_url], council[:name])
  return unless page

  doc = page.parser

  # Try likely card container selectors
  cards = doc.css([
    '.councillor-card',
    '.elected-member',
    '.member-card',
    'article.member',
    '.profile-card',
    '.council-member',
  ].join(', '))

  if cards.empty?
    puts "  WARN: no card selector matched — needs manual inspection"
    # Show a sample of emails found so we know the page loaded
    emails = doc.text.scan(/[a-zA-Z0-9._%+\-]+@cityofpae\.sa\.gov\.au/i).uniq
    puts "  Found #{emails.length} @cityofpae emails on page: #{emails.first(3).inspect}"
    return
  end

  found = 0
  cards.each do |card|
    name_node = card.at_css('h2, h3, h4, .name, .councillor-name, strong')
    next unless name_node

    full_title = name_node.text.strip
    next if full_title.empty?

    role = extract_role(full_title)
    name = clean_name(full_title)
    next if name.empty?

    mailto = card.at_css("a[href^='mailto:']")
    email = mailto ? mailto['href'].sub(/\Amailto:/i, '').strip : extract_email(card.text)

    ward_node = card.at_css('.ward, .ward-name, .subtitle')
    ward = ward_node&.text&.strip

    phone_match = card.text.match(/(\(08\)\s*\d{4}\s*\d{4}|04\d{2}\s*[\d\s]{7,9})/)
    phone = phone_match ? clean_phone(phone_match[0]) : nil

    profile_link = card.at_css("a[href*='member'], a[href*='councillor'], a[href*='mayor']")
    profile_url = if profile_link
      begin; URI.join(council[:members_url], profile_link['href']).to_s; rescue; nil; end
    end

    save_record({
      'name'       => name,
      'role'       => role,
      'ward'       => ward,
      'council'    => council[:name],
      'email'      => email,
      'phone'      => phone,
      'url'        => profile_url,
      'source_url' => council[:members_url],
    })
    found += 1
  end

  puts "  → #{found} members saved" if found > 0
  puts "  WARN: 0 members found — selector may need updating" if found == 0
end

# =============================================================================
# TODO SCRAPER — placeholder for unimplemented councils
# =============================================================================
def scrape_todo(_agent, council)
  puts "\n[#{council[:name]}] TODO — not yet implemented (#{council[:members_url]})"
end

# =============================================================================
# MAIN
# =============================================================================
agent = make_agent

COUNCILS.each do |council|
  case council[:scraper]
  when :opencities then scrape_opencities(agent, council)
  when :pae        then scrape_pae(agent, council)
  when :todo       then scrape_todo(agent, council)
  else
    puts "\nWARN: unknown scraper #{council[:scraper].inspect} for #{council[:name]}"
  end
end

puts "\nDone."
