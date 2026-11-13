defmodule SokochatWeb.LegalCopy do
  @moduledoc "Example legal copy for review. Operator, contacts and retention remain to be confirmed."
  @documents %{
    privacy: %{
      title: "Privacy policy",
      intro: "How information is used when you shop and sell with Sokochat.",
      summary:
        "Shopping conversations help us find products. Confirmed requests share the details a merchant needs to follow up.",
      sections: [
        %{
          id: "information",
          title: "Information we use",
          paragraphs: [
            "For merchant accounts, this includes your name, email address, business profile and catalogue. When you shop on WhatsApp, this includes your phone number, messages, product choices and order requests.",
            "Service records may also include sign-in activity, delivery status and technical logs used to keep the service working. Avoid sending payment PINs, passwords or sensitive personal information in shopping messages."
          ]
        },
        %{
          id: "purpose",
          title: "Why we use it",
          paragraphs: [
            "We use information to manage accounts, find relevant products, generate AI-assisted replies, deliver messages and pass confirmed order requests to the right merchant.",
            "Conversation history helps the assistant understand follow-up questions. Account and technical records help with security, troubleshooting and recovery when something fails."
          ]
        },
        %{
          id: "sharing",
          title: "What merchants and providers see",
          paragraphs: [
            "When you confirm an order request, the product’s merchant receives your phone number and the requested product details so they can follow up. Your full marketplace conversation is not copied into every merchant’s inbox.",
            "WhatsApp and Meta deliver messages. AI and hosting providers process information needed to run the service. Their terms and privacy notices also apply to their services."
          ]
        },
        %{
          id: "storage",
          title: "Storage, cookies and retention",
          paragraphs: [
            "Sokochat uses sign-in cookies and browser storage for settings such as appearance. These help keep your session and preferences working.",
            "Account details, messages and order records are retained while needed to provide the service and meet applicable obligations. A final policy must confirm retention periods, backup handling, provider locations and safeguards for international processing."
          ]
        },
        %{
          id: "choices",
          title: "Your choices",
          paragraphs: [
            "Depending on applicable law, you may request access to your information, correction, deletion, or object to certain processing. Identity verification may be needed before a request can be handled.",
            "Kenya’s Office of the Data Protection Commissioner provides guidance on data-subject rights. The final policy must provide a working contact channel for exercising these rights."
          ],
          link: %{
            label: "Read the ODPC guide to your rights",
            href: "https://www.odpc.go.ke/rights-of-a-data-subject/index.html"
          }
        },
        %{
          id: "contact",
          title: "Contact and updates",
          paragraphs: [
            "This example does not yet identify the legal operator or a dedicated privacy contact. Those details must be confirmed before this draft is used as a published policy.",
            "Material changes should be clearly communicated with an updated policy date. This draft is a starting point for review, not a statement that every legal requirement has been met."
          ]
        }
      ]
    },
    terms: %{
      title: "Terms of service",
      intro: "A plain-language example of how shopping and selling on Sokochat works.",
      summary:
        "Sokochat helps shoppers discover products and send requests. Merchants confirm the sale, delivery and payment.",
      sections: [
        %{
          id: "service",
          title: "Using Sokochat",
          paragraphs: [
            "Sokochat connects shoppers with participating merchants through WhatsApp. AI-assisted replies help you explore their listed products and send an order request to a merchant.",
            "This is an example terms page for the current service. The final version must identify the legal operator, eligibility requirements and the terms that apply to the relationship with each user."
          ]
        },
        %{
          id: "accounts",
          title: "Merchant accounts and listings",
          paragraphs: [
            "Keep your account details, product descriptions, prices and availability accurate. Only upload content and product images you have permission to use, and only list products you are entitled to sell.",
            "Keep your sign-in credentials private. Merchants are responsible for reviewing their listings and confirming the details of a sale with the buyer."
          ]
        },
        %{
          id: "orders",
          title: "Orders, delivery and payment",
          paragraphs: [
            "An order request is a request for merchant follow-up. Sending one does not charge you, reserve stock or confirm delivery. Each merchant receives a separate request for their products.",
            "Before paying, agree with the merchant on the exact product or variant, final price, availability, delivery, returns and refund arrangements. Payments and fulfilment are handled with the merchant."
          ]
        },
        %{
          id: "ai",
          title: "AI-assisted shopping",
          paragraphs: [
            "AI replies can be incomplete or incorrect. Product information comes from merchant listings and should be confirmed with the merchant before you rely on it for a purchase.",
            "Do not send passwords, payment PINs or card security details in a shopping conversation. A reply from the assistant is not proof that a payment has been made or a merchant has accepted an order."
          ]
        },
        %{
          id: "conduct",
          title: "Acceptable use",
          paragraphs: [
            "Use the service lawfully and respect other people. Do not use it for fraud, prohibited products, harassment, misleading listings or attempts to access another person’s account or private information.",
            "Access may be restricted to protect the service or address misuse. The final terms must explain the process for restrictions, account closure and resolving disputes."
          ]
        },
        %{
          id: "contact",
          title: "Your rights and questions",
          paragraphs: [
            "Nothing in this example is intended to remove rights that cannot lawfully be excluded. The final terms should explain responsibility, applicable law and a fair process for complaints.",
            "The legal operator and support contact are still to be confirmed. This draft should be reviewed and completed before it is presented as the service’s binding terms."
          ]
        }
      ]
    }
  }
  def fetch!(page), do: Map.fetch!(@documents, page)
end
