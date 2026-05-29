from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Preformatted, Spacer
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import inch

input_path = 'SPAN_RESCUE_Thesis_Full.docx.md'
output_path = 'SPAN_RESCUE_Thesis_Full.pdf'
with open(input_path, 'r', encoding='utf-8') as f:
    data = f.read()

style = ParagraphStyle(name='Mono', fontName='Courier', fontSize=9, leading=11)
story = []
for chunk in data.split('\n\n'):
    story.append(Preformatted(chunk, style))
    story.append(Spacer(1, 0.1 * inch))

pdf = SimpleDocTemplate(output_path, pagesize=letter, leftMargin=0.5*inch, rightMargin=0.5*inch, topMargin=0.5*inch, bottomMargin=0.5*inch)
pdf.build(story)
print('PDF_CREATED')
