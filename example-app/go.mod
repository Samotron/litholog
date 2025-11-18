module example-app

go 1.21

// For local development, use replace directive
replace github.com/samotron/litholog/bindings/go => ../bindings/go

require github.com/samotron/litholog/bindings/go v0.0.4
