<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="text"/>

  <xsl:template match="TSeq">
    <xsl:value-of select="substring-before(TSeq_accver, '.')"/>
    <xsl:text>&#x9;</xsl:text>
    <xsl:value-of select="TSeq_accver"/>
    <xsl:text>&#x9;</xsl:text>
    <xsl:value-of select="TSeq_gi"/>
    <xsl:text>&#x9;</xsl:text>
    <xsl:value-of select="TSeq_taxid"/>
    <xsl:text>&#x9;</xsl:text>
    <xsl:value-of select="TSeq_sequence"/>
    <xsl:text>&#xA;</xsl:text>
  </xsl:template>

  <xsl:template match="text()">
  </xsl:template>

</xsl:stylesheet>
